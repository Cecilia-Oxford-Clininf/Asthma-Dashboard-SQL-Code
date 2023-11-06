use RCGP_Dashboard
go

----2 minute 43 seconds to run entire script...

----Every time a new measure is added to the dashboard, need to add the category to the numerator and make sure it has the appropriate linking denominator...
---and add a category to the #fw table..

----Set ISOYear and ISOWeek as a from point...
--from the 2019 calendar year until all future weeks as requested by Edinburgh CTU colleagues:
Declare @ISOYear smallint = 2019

Declare @ISOWeek tinyint = 1
declare @time varchar(30)

--create table RCGP_Dashboard.Asthma.PracticeAndNetworkRatesNew (
--	ISOYear smallint not null,
--	ISOWeek tinyint not null,
--	ISOWeekStartDate date not null,
--	ISOWeekEndDate date not null,
--	DateRange varchar(30) not null,
--	PracticeID varchar(6) not null,
--	PracticeorNetwork varchar(8) not null,
--	PracticeKey varchar(6) not null,
--	Category varchar(60) not null,
--	 Constraint PK_Asthma_New_PracticeAndNetworkRates_ISOYear_ISOWeek_PracticeID_PracticeorNetwork_Category
--		primary key (ISOYear asc, ISOWeek asc, PracticeID asc, PracticeorNetwork asc, Category asc),
--	Numerator int null,
--	Denominator int null,
--	Rate decimal(24,8) null,
--	LCI decimal(24,8) null,
--	UCI decimal(24,8) null
--	)

if object_id('tempdb..#AsthmaPracticeLevel') is not null
	drop table #AsthmaPracticeLevel	

Create table #AsthmaPracticeLevel	
(	ISOYear smallint not null,
	ISOWeek int not null,
	PracticeID varchar(6) not null,
	Measure varchar(40) not null
		primary key (PracticeID,ISOYear,ISOWeek,Measure),
	Numerator int null,
	Denominator int null
)

if object_id('tempdb..#AsthmaNetworkLevel') is not null
	drop table #AsthmaNetworkLevel	

Create table #AsthmaNetworkLevel	
(	ISOYear smallint not null,
	ISOWeek int not null,
	Measure varchar(40) not null
		primary key (ISOYear,ISOWeek,Measure),
	Numerator int null,
	Denominator int null
)


-----Creating all the denominators for all the measures needed for tableau..

set @time = convert(varchar(30), getdate(), 114)
raiserror ('Getting denominators %s', 0, 1, @time) with nowait

if object_id('tempdb..#Denoms') is not null
	drop table #Denoms

Select
	pad.ISOYear,
	pad.ISOWeek,
	pad.PracticeID,
	'Denominators' Category,
	Case when Measure='TotalDenominator' then 'Total'
		when Measure='PopulationMale' then 'Male'
		when Measure='PopulationFemale' then 'Female'
		when Measure='Population00to04' then '00-04'
		when Measure='Population05to15' then '05-15'
		when Measure='Population16to64' then '16-64'
		when Measure='Population65Plus' then '65Plus'
		when Measure='AsthmaPrevalence' then 'Asthma' 
		when Measure='Asthma65Plus' then 'Asthma65Plus' --04/05/2023: need this for the AsthmaPneumoVaccine65Plus denominator
		end Measure,
	Result 

Into #Denoms
from RCGP_Dashboard.Asthma.PracticeAggregateDataNew pad

	cross apply (Values(TotalDenominator,'TotalDenominator'),
		(PopulationMale,'PopulationMale'),
		(PopulationFemale,'PopulationFemale'),
		(Population00to04,'Population00to04'),
		(Population05to15,'Population05to15'),
		(Population16to64,'Population16to64'),
		(Population65Plus,'Population65Plus'),
		(AsthmaPrevalence,'AsthmaPrevalence'),
		(Asthma65Plus,'Asthma65Plus') --04/05/2023: need this for the AsthmaPneumoVaccine65Plus denominator
		) as X(Result,Measure)

where pad.ISOYear>=@ISOYear
	and pad.ISOWeek>=@ISOWeek
	and pad.PracticeID<>''

set @time = convert(varchar(30), getdate(), 114)
raiserror ('Getting numerators %s', 0, 1, @time) with nowait

if object_id('tempdb..#Nums') is not null
	drop table #Nums

Select
	pad.ISOYear,
	pad.ISOWeek,
	pad.PracticeID,
	'Numerator' Category,
	------Need a common join for the nums and denoms.  So this 'case when..' turns the measures into a link for the denominators..
	Case when Measure='AsthmaPrevalence' then 'Total'
		when Measure='AsthmaIncidence' then 'Total'
		when Measure='AsthmaMale' then 'Male'
		when Measure='AsthmaFemale' then 'Female'
		when Measure='Asthma00to04' then '00-04'
		when Measure='Asthma05to15' then '05-15'
		when Measure='Asthma16to64' then '16-64'
		when Measure='Asthma65Plus' then '65Plus'
		when Measure='AsthmaPneumoVaccine65Plus' then 'Asthma65Plus' --denominator for PPV vacccinations should be Asthma patients. 04/05/2023: this should also be limited to those aged 65+.
		else 'Asthma'
		end DenominatorCategory,
	X.Measure,
	X.Result

Into #Nums
from RCGP_Dashboard.Asthma.PracticeAggregateDataNew pad

		----Need to unpivot the columns into rows for the dashboard
		cross apply (Values(pad.AsthmaPrevalence,'AsthmaPrevalence'),
							(pad.AsthmaIncidence,'AsthmaIncidence'),
							(pad.AsthmaMale,'AsthmaMale'),
							(pad.AsthmaFemale,'AsthmaFemale'),
							(pad.Asthma00to04,'Asthma00to04'),
							(pad.Asthma05to15,'Asthma05to15'),
							(pad.Asthma16to64,'Asthma16to64'),
							(pad.Asthma65Plus,'Asthma65Plus'),
							(pad.AsthmaExacerbations,'AsthmaExacerbations'),
							(pad.EmergencyDeptAttendance,'EmergencyDeptAttendance'),
							(pad.HospitalAdmission,'HospitalAdmission'),
							(pad.Prednisolone,'Prednisolone'),
							(pad.AsthmaAttack,'AsthmaAttack'),
							(Pad.AsthmaActiveSmoker,'AsthmaActiveSmoker'),
							(Pad.AsthmaExSmoker,'AsthmaExSmoker'),
							(Pad.AsthmaNonSmoker,'AsthmaNonSmoker'),
							(Pad.AsthmaManagementPlanGiven,'AsthmaManagementPlanGiven'),
							(Pad.NoAsthmaManagementPlan,'NoAsthmaManagementPlan'),
							(Pad.AsthmaReviewInLast12Months,'AsthmaReviewInLast12Months'),
							(Pad.AsthmaPneumoVaccine65Plus,'AsthmaPneumoVaccine65Plus')
			) as X(Result,Measure)
	
where pad.ISOYear>=@ISOYear
	and pad.ISOWeek>=@ISOWeek
	and pad.PracticeID<>''


set @time = convert(varchar(30), getdate(), 114)
raiserror ('Combining framework with nums and denoms for practice level %s', 0, 1, @time) with nowait

if object_id('tempdb..#fw') is not null
	drop table #fw 

Create table #fw 
(	ISOYear smallint not null,
	ISOWeek tinyint not null,
	PracticeID varchar(6) not null,
	Category varchar(30) not null
		primary key (PracticeID,Category,ISOWeek,ISOYear)
)
Insert #fw

Select
	ISOYear,
	ISOWeek,
	PracticeID,
	Category

from RCGP_Differential.dbo.PracticeUsage
	cross join (Values ('AsthmaPrevalence'),
							('AsthmaIncidence'),
							('AsthmaMale'),
							('AsthmaFemale'),
							('Asthma00to04'),
							('Asthma05to15'),
							('Asthma16to64'),
							('Asthma65Plus'),
							('AsthmaExacerbations'),
							('EmergencyDeptAttendance'),
							('HospitalAdmission'),
							('Prednisolone'),
							('AsthmaAttack'),
							('AsthmaActiveSmoker'),
							('AsthmaExSmoker'),
							('AsthmaNonSmoker'),
							('AsthmaManagementPlanGiven'),
							('NoAsthmaManagementPlan'),
							('AsthmaReviewInLast12Months'),
							('AsthmaPneumoVaccine65Plus')) as X(Category)


where ISOYear>=@ISOYear
and ISOWeek>=@ISOWeek
and IsPartWeek = 0

Insert #AsthmaPracticeLevel	

Select
	fw.ISOYear,
	fw.ISOWeek,
	fw.PracticeID,
	fw.Category,
	nums.Result Numerator,
	denoms.Result Denominator

from #fw fw
	left outer join #Nums nums
		on fw.PracticeID = nums.PracticeID 
		and fw.Category = nums.Measure
		and fw.ISOWeek = nums.ISOWeek
		and fw.ISOYear = nums.ISOYear
	left outer join #Denoms denoms
		on fw.PracticeID = denoms.PracticeID 
		and fw.ISOWeek = denoms.ISOWeek 
		and fw.ISOYear = denoms.ISOYear 
		and nums.DenominatorCategory = denoms.Measure

set @time = convert(varchar(30), getdate(), 114)
raiserror ('Combining framework with nums and denoms for network  %s', 0, 1, @time) with nowait

Insert #AsthmaNetworkLevel	

Select
	fw.ISOYear,
	fw.ISOWeek,
	fw.Category,
	Sum(nums.Result) Numerator,
	Sum(denoms.Result) Denominator

from #fw fw
	left outer join #Nums nums
		on fw.PracticeID = nums.PracticeID 
		and fw.Category = nums.Measure
		and fw.ISOWeek = nums.ISOWeek
		and fw.ISOYear = nums.ISOYear
	left outer join #Denoms denoms
		on fw.PracticeID = denoms.PracticeID 
		and fw.ISOWeek = denoms.ISOWeek 
		and fw.ISOYear = denoms.ISOYear 
		and nums.DenominatorCategory = denoms.Measure

Group by fw.ISOYear,
	fw.ISOWeek,
	fw.Category


-----Ideally I think the below would be a view, but there is already a view which references the existing summary table, so at this stage
----I'll make this a permanent summary table...

set @time = convert(varchar(30), getdate(), 114)
raiserror ('Combining framework with nums and denoms for network  %s', 0, 1, @time) with nowait

if object_id('tempdb..#asthmadashboardview') is not null
	drop table #asthmadashboardview

Create table #asthmadashboardview
(	ISOYear smallint not null,
	ISOWeek tinyint not null,
	PracticeID varchar(6) not null,
	Measure varchar(50) not null,
	PracticeorNetwork varchar(30) not null,
		primary key (PracticeID,Measure,ISOYear,ISOWeek,PracticeorNetwork),
	Numerator int null,
	Denominator int null
)
Insert #asthmadashboardview

Select
	apl.ISOYear,
	apl.ISOWeek,
	apl.PracticeID,
	apl.Measure,
	'RSC' PracticeorNetwork,
	---IsNull so that we even get a RSC Network for Practices we haven't received in that week...
	anl.Numerator - IsNull(apl.Numerator,0) Numerator,
	anl.Denominator - IsNull(apl.Denominator,0) Denominator 
	
from #AsthmaPracticeLevel apl
	left outer join #AsthmaNetworkLevel anl
		on apl.ISOYear = anl.ISOYear 
		and apl.ISOWeek = anl.ISOWeek 
		and apl.Measure = anl.Measure 

Insert #asthmadashboardview

Select
	apl.ISOYear,
	apl.ISOWeek,
	apl.PracticeID,
	apl.Measure,
	'Practice' PracticeorNetwork,
	apl.Numerator Numerator,
	apl.Denominator Denominator 

from #AsthmaPracticeLevel apl


-----Age StandardisedRate Practice

if object_id('tempdb..#asthmastandardisedrates') is not null
	drop table #asthmastandardisedrates

Create table #asthmastandardisedrates
(	ISOYear smallint not null,
	ISOWeek tinyint not null,
	PracticeID varchar(6) not null,
	Measure varchar(50) not null,
	PracticeorNetwork varchar(30) not null,
		primary key (PracticeID,Measure,ISOYear,ISOWeek,PracticeorNetwork),
	Numerator int null,
	Denominator int null,
	Rate decimal(18,4) null
)
Insert #asthmastandardisedrates

Select
	apl.ISOYear,
	apl.ISOWeek,
	apl.PracticeID,
	'StandardisedAsthmaRate' Measure,
	'Practice' PracticeorNetwork,
	Sum(apl.Numerator) Numerator,
	Sum(apl.Denominator) Denominator,
	Sum(Convert(Decimal(18,4),Numerator)/Nullif(Convert(Decimal(18,4),Denominator),0) * Ons.Proportion)  Rate

from #AsthmaPracticeLevel apl
	inner join Asthma.ONS 
		on Substring(apl.Measure,7,6) = ons.AgeBand

where Measure in ('Asthma00to04','Asthma05to15','Asthma16to64','Asthma65Plus')

Group by apl.ISOYear,
	apl.ISOWeek,
	apl.PracticeID

Insert #asthmastandardisedrates
-----Age StandardisedRate Rest of Network..

Select
	apl.ISOYear,
	apl.ISOWeek,
	apl.PracticeID,
	'StandardisedAsthmaRate' Measure,
	'RSC' PracticeorNetwork,
	---IsNull so that we even get a RSC Network for Practices we haven't received in that week...
	Sum(anl.Numerator - IsNull(apl.Numerator,0)) Numerator,
	Sum(anl.Denominator - IsNull(apl.Denominator,0)) Denominator,
	Sum(Convert(Decimal(18,4),anl.Numerator - IsNull(apl.Numerator,0)) / Convert(Decimal(18,4),anl.Denominator - IsNull(apl.Denominator,0)) * ons.Proportion) Rate 

from #AsthmaPracticeLevel apl
	left outer join #AsthmaNetworkLevel anl
		on apl.ISOYear = anl.ISOYear 
		and apl.ISOWeek = anl.ISOWeek 
		and apl.Measure = anl.Measure 
	inner join Asthma.ONS 
		on Substring(apl.Measure,7,6) = ons.AgeBand

where apl.Measure in ('Asthma00to04','Asthma05to15','Asthma16to64','Asthma65Plus')

Group by apl.ISOYear,
	apl.ISOWeek,
	apl.PracticeID

	
if object_id('tempdb..#AsthmaSummaryRatesCombined') is not null
	drop table #AsthmaSummaryRatesCombined	

Select
	adv.ISOYear,
	adv.ISOWeek,
	adv.PracticeID,
	adv.PracticeorNetwork,
	adv.Measure,
	adv.Numerator,
	Adv.Denominator,
	Convert(Decimal(18,4),Numerator)/Nullif(Convert(Decimal(18,4),Denominator),0) Rate

Into #AsthmaSummaryRatesCombined
from #asthmadashboardview adv

Union all

Select
	asr.ISOYear,
	asr.ISOWeek,
	asr.PracticeID,
	asr.PracticeorNetwork,
	asr.Measure,
	asr.Numerator,
	asr.Denominator,
	asr.Rate

from #asthmastandardisedrates asr


truncate table Asthma.PracticeAndNetworkRatesNew

Insert Asthma.PracticeAndNetworkRatesNew

Select
	asrc.ISOYear,
	asrc.ISOWeek,
	iso.ISOWeekStartDate,
	iso.ISOWeekEndDate,
	Convert(Varchar(10),iso.ISOWeekStartDate)+ ' - '+ Convert(Varchar(10),iso.ISOWeekEndDate) DateRange,
	asrc.PracticeID,
	asrc.PracticeorNetwork,
	pkey.Practice PracticeKey,
	asrc.Measure Category,
	asrc.Numerator,
	cci.Denominator,
	cci.Rate,
	cci.LCI,
	cci.UCI

from #AsthmaSummaryRatesCombined asrc
	cross apply library.dbo.CalculateConfidenceIntevals(asrc.Denominator,asrc.rate) cci
	inner join library.dbo.ISOWeek iso
			on asrc.ISOYear = iso.ISOYear
			and asrc.ISOWeek = iso.ISOWeek
----Note that it will not include practices without a practice key...
	inner join RCGP_WR.dbo.NEWS_NHSOrganisation_Online pkey
		on asrc.PracticeID = pkey.NHSOrganisationCode


