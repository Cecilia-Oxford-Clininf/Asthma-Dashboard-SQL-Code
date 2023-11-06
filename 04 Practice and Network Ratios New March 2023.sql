Use RCGP_Dashboard
go

----Set ISOYear and ISOWeek as a from point...

--from the 2019 calendar year until all future weeks as requested by Edinburgh CTU colleagues:
Declare @ISOYear smallint = 2019
Declare @ISOWeek tinyint = 1

--create table RCGP_Dashboard.Asthma.PracticeAndNetworkRatioNew (
--	ISOYear smallint not null,
--	ISOWeek tinyint not null,
--	ISOWeekStartDate date not null,
--	ISOWeekEndDate date not null,
--	DateRange varchar(30) not null,
--	PracticeID varchar(6) not null,
--	PracticeOrNetwork varchar(30) not null,
--		Constraint PK_Asthma_New_PracticeAndNetworkRatio_PracticeID_ISOYear_ISOWeek_PracticeOrNetwork 
--			Primary key (PracticeID asc, ISOYear asc, ISOWeek asc, PracticeOrNetwork asc),
--	PracticeKey varchar(6) not null,
--	InhaledRelievers int null,
--	Preventers int null,
--	InhalertoPreventerRatioSTDEV decimal(24,8) null,
--	Ratio decimal(24,8) null,
--	LCI decimal(24,8) null,
--	UCI decimal(24,8) null
--	)

Truncate table Asthma.PracticeAndNetworkRatioNew

if object_id('tempdb..#PracticeRatios') is not null
	drop table #PracticeRatios

Create table #PracticeRatios
(	ISOYear smallint not null,
	ISOWeek tinyint not null,
	PracticeID varchar(6) not null,
	InhaledRelievers int null,
	Preventers int null,
	InhalertoPreventerRatioSTDEVforNetworkIncludingPractice decimal(24,8) null,
	InhalertoPreventerRatioSTDEVforNetworkExcludingPractice decimal(24,8) null
)


Insert #PracticeRatios
Select
	pu.ISOYear,
	pu.ISOWeek,
	pu.PracticeID,
	pad.InhaledRelievers,
	pad.Preventers,
	pad.InhalertoPreventerRatioSTDEVforNetworkIncludingPractice,
	----This is to deal with Practices which don't have any asthma patients...
	IsNull(pad.InhalertoPreventerRatioSTDEVforNetworkExcludingPractice,pad.InhalertoPreventerRatioSTDEVforNetworkIncludingPractice) InhalertoPreventerRatioSTDEVforNetworkExcludingPractice

from RCGP_Differential.dbo.PracticeUsage pu
		left outer join RCGP_Dashboard.Asthma.PracticeAggregateDataNew pad
			on pu.ISOYear = pad.iSOYear 
			and pu.ISOWeek = pad.ISOWeek 
			and pu.PracticeID = pad.PracticeID

where pu.ISOYear>=@ISOYear
	and pu.ISOWeek>=@ISOWeek
	and pu.IsPartWeek = 0
------for practices which  has data for a particular week
	and pad.PracticeID is not null


; with base as
(
	Select
		pu.ISOYear,
		pu.ISOWeek,
		pu.PracticeID,
		pad.InhaledRelievers,
		pad.Preventers,
		pad.InhalertoPreventerRatioSTDEVforNetworkIncludingPractice,
		IsNull(pad.InhalertoPreventerRatioSTDEVforNetworkExcludingPractice,pad.InhalertoPreventerRatioSTDEVforNetworkIncludingPractice) InhalertoPreventerRatioSTDEVforNetworkExcludingPractice

	from RCGP_Differential.dbo.PracticeUsage pu
			left outer join RCGP_Dashboard.Asthma.PracticeAggregateDataNew pad
				on pu.ISOYear = pad.iSOYear 
				and pu.ISOWeek = pad.ISOWeek 
				and pu.PracticeID = pad.PracticeID

	where pu.ISOYear>=@ISOYear
		and pu.ISOWeek>=@ISOWeek
		and pu.IsPartWeek = 0
		----deal with practices which doesn't has data for a particular week
		and pad.PracticeID is null
),
	missingratios as
(
	Select
		Distinct 
		ISOYear,
		ISOWeek,
		InhalertoPreventerRatioSTDEVforNetworkIncludingPractice

	from RCGP_Dashboard.Asthma.PracticeAggregateDataNew
)
Insert #PracticeRatios

Select
	base.ISOYear,
	base.ISOWeek,
	base.PracticeID,
	base.InhaledRelievers,
	base.Preventers,
	base.InhalertoPreventerRatioSTDEVforNetworkIncludingPractice,
	----This is to deal with Practices which don't have any asthma patients...
	mr.InhalertoPreventerRatioSTDEVforNetworkIncludingPractice InhalertoPreventerRatioSTDEVforNetworkExcludingPractice
from base 
	inner join missingratios mr
		on base.ISOYear = mr.ISOYear 
		and base.ISOWeek = mr.ISOWeek



; with combinedratios as
(
	Select
		ISOYear,
		ISOWeek,
		PracticeID,
		'Practice' PracticeOrNetwork,
		InhaledRelievers,
		Preventers,
		InhalertoPreventerRatioSTDEVforNetworkIncludingPractice InhalertoPreventerRatioSTDEV
	
	from #PracticeRatios

	Union all
	
	Select
		ISOYear,
		ISOWeek,
		PracticeID,
		'RSC' PracticeOrNetwork,
		Sum(InhaledRelievers) over (Partition by ISOYear,ISOWeek) - IsNull(InhaledRelievers,0) InhaledRelievers,
		Sum(Preventers) over (Partition by ISOYear,ISOWeek) - IsNull(Preventers,0) Preventers,
		InhalertoPreventerRatioSTDEVforNetworkExcludingPractice InhalertoPreventerRatioSTDEV

	from #PracticeRatios
)
Insert Asthma.PracticeAndNetworkRatioNew

Select
	cr.ISOYear,
	cr.ISOWeek,
	iso.ISOWeekStartDate,
	iso.ISOWeekEndDate,
	Convert(Varchar(10),iso.ISOWeekStartDate)+ ' - '+ Convert(Varchar(10),iso.ISOWeekEndDate) DateRange,
	cr.PracticeID,
	cr.PracticeOrNetwork,
	pkey.Practice PracticeKey,
	cr.InhaledRelievers,
	cr.Preventers,
	cr.InhalertoPreventerRatioSTDEV,
	ci.Ratio,
	ci.LCI,
	ci.UCI

from combinedratios cr
	cross apply dbo.CalculateConfidenceIntevalsForDrugRatios(Convert(Decimal(18,4),cr.InhaledRelievers),Convert(Decimal(18,4),cr.Preventers),cr.InhalertoPreventerRatioSTDEV) ci
	inner join library.dbo.ISOWeek iso
			on cr.ISOYear = iso.ISOYear
			and cr.ISOWeek = iso.ISOWeek
	inner join RCGP_WR.dbo.NEWS_NHSOrganisation_Online pkey
		on cr.PracticeID = pkey.NHSOrganisationCode


