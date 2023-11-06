use RCGP_Differential
go

--from the 2019 calendar year until all future weeks as requested by Edinburgh CTU colleagues:
--took 14 hours 45 minutes to run data from 2019. But when this script is re-run, 
--only data for weeks not included in the data will be extracted.
declare @StudyStartWeek int = 201901

declare @DifferentialLatestWeek int

--create table RCGP_Dashboard.Asthma.PracticeAggregateDataNew (
--	ISOYear smallint not null,
--	ISOWeek tinyint not null,
--		Constraint PK_RCGP_Dashboard_Asthma_New_PracticeAggregateData_PracticeID_ISOYear_ISOWeek
--			primary key (PracticeID asc, ISOYear asc, ISOWeek asc),
--	ISOWeekStartDate date not null,
--	ISOWeekEndDate date not null,
--	PracticeID varchar(6) not null,
--	TotalDenominator int null,
--	AsthmaPrevalence int null,
--	AsthmaIncidence int null,
--	AsthmaMale int null,
--	AsthmaFemale int null,
--	Asthma00to04 int null,
--	Asthma05to15 int null,
--	Asthma16to64 int null,
--	Asthma65Plus int null,
--	AsthmaExacerbations int null,
--	EmergencyDeptAttendance int null,
--	HospitalAdmission int null,
--	Prednisolone int null,
--	AsthmaAttack int null,
--	NoExacerbations int null,
--	EmergencyDeptAttendanceMale int null,
--	HospitalAdmissionMale int null,
--	PrednisoloneMale int null,
--	AsthmaAttackMale int null,
--	EmergencyDeptAttendanceFeMale int null,
--	HospitalAdmissionFeMale int null,
--	PrednisoloneFeMale int null,
--	AsthmaAttackFeMale int null,
--	AsthmaManagementPlanGiven int null,
--	NoAsthmaManagementPlan int null,
--	AsthmaReviewInLast12Months int null,
--	AsthmaActiveSmoker int null,
--	AsthmaNonSmoker int null,
--	AsthmaExSmoker int null,
--	AsthmaUnknownSmokerStatus int null,
--	PopulationMale int null,
--	PopulationFemale int null,
--	Population00to04 int null,
--	Population05to15 int null,
--	Population16to64 int null,
--	Population65Plus int null,
--	PopulationActiveSmoker int null,
--	PopulationNonSmoker int null,
--	PopulationExSmoker int null,
--	AsthmaPneumoVaccine65Plus int null,
--	InhaledRelievers int null,
--	Preventers int null,
--	InhalertoPreventerRatioSTDEVforNetworkIncludingPractice decimal(24,8) null,
--	InhalertoPreventerRatioSTDEVforNetworkExcludingPractice decimal(24,8) null
--)

--Latest week which has had all the appropriate differential processes run
select top 1 @DifferentialLatestWeek = wk.ISOYearAndWeek
from PracticeUsage pu
inner join Library.dbo.ISOWeek wk
	on wk.ISOYear = pu.ISOYear
	and wk.ISOWeek = pu.ISOWeek
inner join ProcessRunByDate pr
	on pr.Script = 'PracticeUsage'
	and wk.ISOWeekEndDate < pr.EndTime
where pu.IsPartWeek = 0
order by wk.ISOYearAndWeek desc

if object_id('tempdb..#Weeks') is not null
	drop table #Weeks

create table #Weeks (
	ISOYear smallint not null,
	ISOWeek tinyint not null,
	primary key (ISOYear,ISOWeek),
	ISOYearAndWeek int not null,
	ISOWeekStartDate date not null,
	ISOWeekEndDate date not null
)

insert #Weeks
select wk.ISOYear,
	wk.ISOWeek,
	wk.ISOYearAndWeek,
	wk.ISOWeekStartDate,
	wk.ISOWeekEndDate
from Library.dbo.ISOWeek wk
where wk.ISOYearAndWeek between @StudyStartWeek and @DifferentialLatestWeek
and not exists (select *
			from RCGP_Dashboard.Asthma.PracticeAggregateDataNew pad
			where pad.ISOYear = wk.ISOYear
			and pad.ISOWeek = wk.ISOWeek)

declare @ISOYearAndWeek int = 0

while 1 = 1
begin
	declare @ISOYear smallint
	declare @ISOWeek tinyint
	declare @StartDate date
	declare @ISOWeekStartDate date
	declare @EndDate date

	declare @time varchar(30)
	declare @debugweek varchar(6)
	
	select top 1 @ISOYearAndWeek = ISOYearAndWeek,
		@debugweek = convert(varchar(6),ISOYearAndWeek),
		@ISOYear = ISOYear,
		@ISOWeek = ISOWeek,
		----Making sure there is 12 weeks of registration for each patient as we need to make sure  there is 12 weeks prescription history for the inhaler to preventer ratio..
		@StartDate = DateAdd(Week,-12,ISOWeekStartDate),
		@ISOWeekStartDate = ISOWeekStartDate,
		@EndDate = ISOWeekEndDate
	from #Weeks
	where ISOYearAndWeek > @ISOYearAndWeek
	order by ISOYearAndWeek
	if @@rowcount = 0
		break

	print @debugweek
	print @StartDate
	print @ISOWeekStartDate
	print @EndDate
	
	set @time = convert(varchar(30), getdate(), 114)
	raiserror ('Getting all Patients  %s %s', 0, 1, @debugweek, @time) with nowait

-------After conversation with Simon, going to use PRIMIS Definition of Asthma, rather than the ontology...

if object_id('tempdb..#AsthmaPatients') is not null
	drop table #AsthmaPatients

Create table #AsthmaPatients
(	ISOYear smallint not null,
	ISOWeek tinyint not null,
	StartDate date not null,
	ISOWeekStartDate date not null,
	ISOWeekEndDate date not null,
	PracticeID varchar(6) not null,
	PseudoID int not null
		primary key (PracticeID,PseudoID,ISOWeekStartDate),
	Birthday date null,
	Sex varchar(1) not null,
	Age tinyint null,
	AsthmaPrevalence bit not null,
	AsthmaIncident bit not null
)

Insert #AsthmaPatients


select @ISOYear,
	@ISOWeek,
	@StartDate, --12 weeks before ISO week start date
	@ISOWeekStartDate,
	@EndDate,
	den.PracticeID,
	den.PseudoID,
	den.Birthday,
	den.Sex,
	Age.Age,
	Case when Max(prg.StartDate) <= @EndDate then 1 else 0 end AsthmaPrevalence, 
	Case when Min(prg.StartDate) between @StartDate and @EndDate then 1 else 0 end AsthmaIncident --incidence within the last 3 months...
	
from dbo.DenominatorPatientsNoAgesForDashboard(@StartDate,@EndDate) den --registered for 12 weeks before ISO week start date
	cross apply library.dbo.AgeAtDate(den.birthday,@EndDate) Age --calculated at end of the week to allow for births during the week
	left outer join dbo.PatientPRIMISRiskGroup prg
		on den.PracticeID = prg.PracticeID 
		and den.PseudoID = prg.PseudoID 
		and prg.RiskGroupName='Asthma'
		and prg.StartDate <= @EndDate
		and EndDateNoNulls >= @ISOWeekStartDate

-----Need this in the where clause as tinyint overflow -1...
where Age.Age>=0 

Group by den.PracticeID,
	den.PseudoID,
	den.Birthday,
	den.Sex,
	Age.Age


set @time = convert(varchar(30), getdate(), 114)
	raiserror ('Getting AsthmaExacerbations  %s %s', 0, 1, @debugweek, @time) with nowait


if object_id('tempdb..#AsthmaExacerbations') is not null
	drop table #AsthmaExacerbations

Create table #AsthmaExacerbations
(	ISOYear smallint not null,
	ISOWeek tinyint not null,
	ISOWeekStartDate date not null,
	ISOWeekEndDate date not null,
	PracticeID varchar(6) not null,
	PseudoID int not null
		primary key (PracticeID,PseudoID,ISOWeekStartDate),
	Prednisolone bit not null,
	AsthmaAttack bit not null,
	HospitalAdmission bit not null,
	EmergencyDeptAttendance bit not null
)

; with base as
(
	Select
		ap.ISOYear,
		ap.ISOWeek,
		Ap.ISOWeekStartDate,
		ap.ISOWeekEndDate,
		ap.PracticeID,
		ap.PseudoID,
		ind.CategoryOrDrugName ExacerbationType,
		ind.IndicatorDate ExacerbationDate

	from #AsthmaPatients ap
		inner join RCGP_Dashboard.Asthma.PatientIndicatorNew ind
			on ap.PracticeID = ind.PracticeID 
			and ap.PseudoID = ind.PseudoID 
			and ind.IndicatorDate between DateAdd(Week,-4,ap.ISOWeekStartDate) and ap.ISOWeekEndDate
			and ind.CategoryOrDrugName in ('AsthmaExacerbation','Prednisolone')

	where AsthmaPrevalence=1
)
Insert #AsthmaExacerbations

Select 
	base.ISOYear,
	base.ISOWeek,
	base.ISOWeekStartDate,
	base.ISOWeekEndDate,
	base.PracticeID,
	base.PseudoID,
	Max(Case when base.ExacerbationType='Prednisolone' then 1 else 0 end) Prednisolone,
	Max(Case when base.ExacerbationType='AsthmaExacerbation' then 1 else 0 end) AsthmaAttack,
	Max(Case when ind.CategoryorDrugName='HospitalAdmission' then 1 else 0 end) HospitalAdmission,
	Max(Case when ind.CategoryorDrugName='SeenInHospitalCasualty' then 1 else 0 end) EmergencyDeptAttendance

from base 
	left outer join RCGP_Dashboard.Asthma.PatientIndicatorNew ind
		on base.PracticeID = ind.PracticeID 
		and base.PseudoID = ind.PseudoID 
		and ind.IndicatorDate between DateAdd(Day,-7,ExacerbationDate) and DateAdd(Day,7,ExacerbationDate)
		and ind.CategoryorDrugName in ('SeenInHospitalCasualty','HospitalAdmission')

Group by base.ISOYear,
	base.ISOWeek,
	base.ISOWeekStartDate,
	base.ISOWeekEndDate,
	base.PracticeID,
	base.PseudoID


set @time = convert(varchar(30), getdate(), 114)
	raiserror ('Getting Asthma Relievers and Preventers  %s %s', 0, 1, @debugweek, @time) with nowait

-----Decided to use 12 weeks worth of prescription data for a better representation for this ratio...

If object_id('tempdb..#AsthmaRelieversAndPreventers') is not null
	drop table #AsthmaRelieversAndPreventers

Create table #AsthmaRelieversAndPreventers
(	ISOYear smallint not null,
	ISOWeek tinyint not null,
	ISOWeekStartDate date not null,
	ISOWeekEndDate date not null,
	PracticeID varchar(6) not null,
	PseudoID int not null
		primary key (PracticeID,PseudoID,ISOWeekStartDate),
	InhaledRelievers int not null,
	Preventers int not null,
	InhalertoPreventerRatio decimal(24,8) null
)


; with base as
(
	Select
		ap.ISOYear,
		ap.ISOWeek,
		ap.ISOWeekStartDate,
		ap.ISOWeekEndDate,
		ap.PracticeID,
		ap.PseudoID,
		Nullif(Sum(Case when ind.CategoryorDrugName in ('Beta2AdrenoceptorAgonistsSelective','Antimuscarinics') then 1 else 0 end),0) InhaledRelievers,
		Nullif(Sum(Case when ind.CategoryorDrugName in ('CorticosteroidsInhaled') then 1 else 0 end),0) Preventers,
	
			Convert(Decimal(24,8),nullif(Sum(Case when ind.CategoryorDrugName in ('Beta2AdrenoceptorAgonistsSelective','Antimuscarinics') then 1 else 0 end),0))/
				Convert(Decimal(24,8),nullif(Sum(Case when ind.CategoryorDrugName in ('CorticosteroidsInhaled') then 1 else 0 end),0)) 
					InhalertoPreventerRatio

	from #AsthmaPatients ap
		inner join RCGP_Dashboard.Asthma.PatientIndicatorNew ind
			on ap.PracticeID = ind.PracticeID 
			and ap.PseudoID = ind.PseudoID 
			and ind.IndicatorDate between ap.ISOWeekStartDate and ap.ISOWeekEndDate
		
	where ap.AsthmaPrevalence=1
	and ind.CategoryorDrugName in (
	'CorticosteroidsInhaled',
	'Antimuscarinics',
	'Beta2AdrenoceptorAgonistsSelective'
	)

	Group by ap.ISOYear,
		ap.ISOWeek,
		ap.ISOWeekStartDate,
		ap.ISOWeekEndDate,
		ap.PracticeID,
		ap.PseudoID
)
Insert #AsthmaRelieversAndPreventers

Select
	ISOYear,
	ISOWeek,
	ISOWeekStartDate,
	ISOWeekEndDate,
	PracticeID,
	PseudoID,
	InhaledRelievers,
	Preventers,
	InhalertoPreventerRatio

from base 

----Only want to include asthma patients with a valid ratio (need to have a count for both relievers and preventers..)
where InhaledRelievers is not null 
	and Preventers is not null



set @time = convert(varchar(30), getdate(), 114)
	raiserror ('Getting Inhaler to Preventer Ratio for RestofNetwork STDEV  %s %s', 0, 1, @debugweek, @time) with nowait

------Need to find the standard deviation for the reliever to preventer ratio for the rest of the network for each practice,
---so need to do a cross join for each practice to the rest of the network, excluding that practice....

If object_id('tempdb..#InhalertoPreventerRatioRestofNetworkSTDEV') is not null
	drop table #InhalertoPreventerRatioRestofNetworkSTDEV

; with resofnetworkratio as
(
	Select 
		Distinct 
		arp.PracticeID,
		arp2.PracticeID RestofNetworkPracticeIDs

	from #AsthmaRelieversAndPreventers arp
		Cross join #AsthmaRelieversAndPreventers arp2

	where Arp.PracticeID <>Arp2.PracticeID 
)
Select
	rn_ratio.practiceID,
	STDEV(arp3.InhalertoPreventerRatio) InhalertoPreventerRatioRestofNetworkSTDEV

Into #InhalertoPreventerRatioRestofNetworkSTDEV
from resofnetworkratio rn_ratio
	inner join #AsthmaRelieversAndPreventers arp3
		on rn_ratio.RestofNetworkPracticeIDs = arp3.PracticeID

Group by rn_ratio.PracticeID


set @time = convert(varchar(30), getdate(), 114)
	raiserror ('Getting  Patient Smoking Status  %s %s', 0, 1, @debugweek, @time) with nowait


if OBJECT_ID('tempdb..#SmokingDayHierarchy') is not null
	drop table #SmokingDayHierarchy
	
Select
	ap.ISOYear,
	ap.ISOWeek,
	ap.ISOWeekStartDate,
	ap.ISOWeekEndDate,
	ap.PracticeID,
	ap.PseudoID,
	Se.StatusStartDate IndicatorDate,
	Min(Case when se.ThisStatus='ActiveSmoker' then 1 
			when se.ThisStatus='Non-smoker' then 2
			when se.ThisStatus='Ex-Smoker' then 3
			end) HierarchyDay

Into #SmokingDayHierarchy
from #AsthmaPatients ap
		inner join RCGP_Differential.HealthIndicators.SmokingEvents se
			on ap.PracticeID = Se.PracticeID 
			and ap.PseudoID = Se.pseudoID 
			and Se.StatusStartDate<=@StartDate

Group by ap.ISOYear,
	ap.ISOWeek,
	ap.ISOWeekStartDate,
	ap.ISOWeekEndDate,
	ap.PracticeID,
	ap.PseudoID,
	Se.StatusStartDate


if object_id('tempdb..#AsthmaPatientSmokingStatus') is not null
	drop table #AsthmaPatientSmokingStatus

Create table #AsthmaPatientSmokingStatus
(	ISOYear smallint not null,
	ISOWeek tinyint not null,
	ISOWeekStartDate date not null,
	ISOWeekEndDate date not null,
	PracticeID varchar(6) not null,
	PseudoID int not null
		primary key (PracticeID,PseudoID,ISOWeekStartDate),
	AdjustedSmokingStatus varchar(1) null
)

Insert #AsthmaPatientSmokingStatus

Select
	ISOYear,
	ISOWeek,
	ISOWeekStartDate,
	ISOWeekEndDate,
	PracticeID,
	PseudoID,
	Case when Substring(Max(convert(varchar(8),IndicatorDate,112) + convert(varchar(1),HierarchyDay)),9,1)='2' 
		and Substring(Max(convert(varchar(8),IndicatorDate,112) + convert(varchar(50),HierarchyDay)),9,1) <> MIN(Case when HierarchyDay IN ('1','3') then '1' else '2' end) then '3' 
			else Substring(Max(convert(varchar(8),IndicatorDate,112) + convert(varchar(50),HierarchyDay)),9,1) end AdjustedSmokingStatus

from #SmokingDayHierarchy

Group by ISOYear,
	ISOWeek,
	ISOWeekStartDate,
	ISOWeekEndDate,
	PracticeID,
	PseudoID


set @time = convert(varchar(30), getdate(), 114)
	raiserror ('Getting Asthma Management Plans  %s %s', 0, 1, @debugweek, @time) with nowait

if object_id('tempdb..#AsthmaManagementPlan') is not null
	drop table #AsthmaManagementPlan

Create table #AsthmaManagementPlan
(	ISOYear smallint not null,
	ISOWeek tinyint not null,
	ISOWeekStartDate date not null,
	ISOWeekEndDate date not null,
	PracticeID varchar(6) not null,
	PseudoID int not null
		primary key (PracticeID,PseudoID,ISOWeekStartDate),
	AsthmaManagementPlanGiven bit not null,
	AsthmaManagementPlanDeclined bit not null
)

Insert #AsthmaManagementPlan

Select
	ap.ISOYear,
	ap.ISOWeek,
	ap.ISOWeekStartDate,
	ap.ISOWeekEndDate,
	ap.PracticeID,
	ap.PseudoID,
	Case when Substring(Max(Convert(Varchar(8),ind.IndicatorDate,112) + ind.CategoryorDrugName),9,50)='AsthmaManagementPlan' then 1 else 0 end AsthmaManagementPlanGiven,
	Case when Substring(Max(Convert(Varchar(8),ind.IndicatorDate,112) + ind.CategoryorDrugName),9,50)='AsthmaManagementNoPlan' then 1 else 0 end AsthmaManagementPlanDeclined

from #AsthmaPatients ap
	inner join RCGP_Dashboard.Asthma.PatientIndicatorNew ind
		on ap.PracticeID = ind.PracticeID 
		and ap.PseudoID = ind.PseudoID 
		and ind.IndicatorDate<=ap.ISOWeekEndDate
		and ind.CategoryorDrugName in ('AsthmaManagementPlan','AsthmaManagementNoPlan')

where ap.AsthmaPrevalence=1

group by ap.ISOYear,
	ap.ISOWeek,
	ap.ISOWeekStartDate,
	ap.ISOWeekEndDate,
	ap.PracticeID,
	ap.PseudoID


set @time = convert(varchar(30), getdate(), 114)
	raiserror ('Getting Pneumo Vaccine  %s %s', 0, 1, @debugweek, @time) with nowait

if object_id('tempdb..#PneumoVaccine') is not null
	drop table #PneumoVaccine

Create table #PneumoVaccine
(	ISOYear smallint not null,
	ISOWeek tinyint not null,
	ISOWeekStartDate date not null,
	ISOWeekEndDate date not null,
	PracticeID varchar(6) not null,
	PseudoID int not null
		primary key (PracticeID,PseudoID,ISOWeekStartDate),
	PneumoVaccine bit not null
)

Insert #PneumoVaccine

Select
	ap.ISOYear,
	ap.iSOWeek,
	ap.ISOWeekStartDate,
	ap.ISOWeekEndDate,
	ap.PracticeID,
	ap.PseudoID,
	Max(Case when vp.VaccinationDate is not null then 1 else 0 end) PneumoVaccine 

from #AsthmaPatients ap
	inner join RCGP_Dashboard.Pneumo.VaccinatedPatients vp
		on ap.PracticeID = vp.PracticeID 
		and ap.PseudoID = vp.PseudoID 
		and vp.VaccinationDate <= ap.ISOWeekEndDate 

Group by ap.ISOYear,
	ap.ISOWeek,
	ap.ISOWeekStartDate,
	ap.ISOWeekEndDate,
	ap.PracticeID,
	ap.PseudoID


set @time = convert(varchar(30), getdate(), 114)
	raiserror ('Getting Asthma Reviews  %s %s', 0, 1, @debugweek, @time) with nowait

if object_id('tempdb..#AsthmaReviews') is not null
	drop table #AsthmaReviews

Select
	Distinct 
	ap.ISOYear,
	ap.ISOWeek,
	ap.ISOWeekStartDate,
	ap.ISOWeekEndDate,
	ap.PracticeID,
	ap.PseudoID,
	1 AsthmaReviewInLast12Months

Into #AsthmaReviews
from #AsthmaPatients ap
	inner join RCGP_Dashboard.Asthma.PatientIndicatorNew ind
		on ap.PracticeID = ind.PracticeID 
		and ap.PseudoID = ind.PseudoID 
		and ind.CategoryorDrugName='AsthmaReview'
		and ind.IndicatorDate between DateAdd(Month,-12,ap.ISOWeekEndDate) and ap.ISOWeekEndDate

where ap.AsthmaPrevalence=1


set @time = convert(varchar(30), getdate(), 114)
	raiserror ('Creating patient table for week  %s %s', 0, 1, @debugweek, @time) with nowait

if object_id('tempdb..#AllAsthmaPatients') is not null
	drop table #AllAsthmaPatients 

Select
	ap.ISOYear,
	ap.ISOWeek,
	ap.ISOWeekStartDate,
	ap.ISOWeekEndDate,
	ap.PracticeID,
	ap.PseudoID,
	ap.Age,
	ap.Sex,
	ap.AsthmaPrevalence,
	ap.AsthmaIncident,
	Case when aex.EmergencyDeptAttendance=1 then 'EmergencyDeptAttendance'
		when aex.HospitalAdmission = 1 then 'HospitalAdmission'
		when aex.Prednisolone=1 then 'Prednisolone'
		when aex.AsthmaAttack=1 then 'AsthmaAttack'
		else 'None' end AsthmaExacerbation,
	amp.AsthmaManagementPlanGiven,
	amp.AsthmaManagementPlanDeclined,
	Case when ss.AdjustedSmokingStatus='1' then 'ActiveSmoker' 
			when ss.AdjustedSmokingStatus='2' then 'Non-smoker'
			when ss.AdjustedSmokingStatus='3' then 'Ex-Smoker'				
			else 'Unknown' end AdjustedSmokingStatus,
	arp.InhaledRelievers,
	arp.Preventers,
	STDEV(arp.InhalertoPreventerRatio) over () InhalertoPreventerRatioSTDEVforNetworkIncludingPractice,
	pv.PneumoVaccine,
	ar.AsthmaReviewInLast12Months

Into #AllAsthmaPatients 

from #AsthmaPatients ap
	left outer join #AsthmaExacerbations aex
		on ap.PracticeID = aex.PracticeID 
		and ap.PseudoiD = aex.Pseudoid
	left outer join #AsthmaManagementPlan amp
		on ap.PracticeID = amp.PracticeID 
		and ap.PseudoID = amp.PseudoID 
	left outer join #AsthmaPatientSmokingStatus ss
		on ap.PracticeID = ss.PracticeID 
		and ap.pseudoID = ss.pseudoID
	left outer join #AsthmaRelieversAndPreventers arp
		on ap.PracticeID = arp.PracticeID 
		and ap.PseudoID = arp.PseudoID 
	left outer join #PneumoVaccine pv
		on ap.PracticeiD = pv.PracticeID 
		and ap.PseudoID = pv.PseudoID 
	left outer join #AsthmaReviews ar
		on ap.PracticeID = ar.PracticeID 
		and ap.PseudoID = ar.PseudoID

set @time = convert(varchar(30), getdate(), 114)
	raiserror ('Putting aggregate figures into practice table  %s %s', 0, 1, @debugweek, @time) with nowait

Insert RCGP_Dashboard.Asthma.PracticeAggregateDataNew

Select
	ISOYear,
	ISOWeek,
	ISOWeekStartDate,
	ISOWeekEndDate,
	aap.PracticeID,
	Count(*) TotalDenominator,
	
	Sum(Case when AsthmaPrevalence=1 then 1 else 0 end) AsthmaPrevalence,
	Sum(Case when AsthmaIncident=1 then 1 else 0 end) AsthmaIncidence,
	Sum(Case when AsthmaPrevalence=1 and Sex='M' then 1 else 0 end) AsthmaMale,
	Sum(Case when AsthmaPrevalence=1 and Sex='F' then 1 else 0 end) AsthmaFemale,
	Sum(Case when AsthmaPrevalence=1 and Age between 0 and 4 then 1 else 0 end) Asthma00to04,
	Sum(Case when AsthmaPrevalence=1 and Age between 5 and 15 then 1 else 0 end) Asthma05to15,
	Sum(Case when AsthmaPrevalence=1 and Age between 16 and 64 then 1 else 0 end) Asthma16to64,
	Sum(Case when AsthmaPrevalence=1 and Age>=65 then 1 else 0 end) Asthma65Plus,

	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation<>'None' then 1 else 0 end) AsthmaExacerbations,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='EmergencyDeptAttendance' then 1 else 0 end) EmergencyDeptAttendance,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='HospitalAdmission' then 1 else 0 end) HospitalAdmission,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='Prednisolone' then 1 else 0 end) Prednisolone,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='AsthmaAttack' then 1 else 0 end) AsthmaAttack,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='NoExacerbations' then 1 else 0 end) NoExacerbations,

	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='EmergencyDeptAttendance' and Sex='M' then 1 else 0 end) EmergencyDeptAttendanceMale,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='HospitalAdmission' and Sex='M'  then 1 else 0 end) HospitalAdmissionMale,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='Prednisolone' and Sex='M'  then 1 else 0 end) PrednisoloneMale,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='AsthmaAttack' and Sex='M'  then 1 else 0 end) AsthmaAttackMale,

	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='EmergencyDeptAttendance' and Sex='F' then 1 else 0 end) EmergencyDeptAttendanceFeMale,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='HospitalAdmission' and Sex='F'  then 1 else 0 end) HospitalAdmissionFeMale,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='Prednisolone' and Sex='F'  then 1 else 0 end) PrednisoloneFeMale,
	Sum(Case when AsthmaPrevalence=1 and AsthmaExacerbation='AsthmaAttack' and Sex='F'  then 1 else 0 end) AsthmaAttackFeMale,

	Sum(Case when AsthmaPrevalence=1 and AsthmaManagementPlanGiven=1 then 1 else 0 end) AsthmaManagementPlanGiven,
	Sum(Case when AsthmaPrevalence=1 and AsthmaManagementPlanDeclined=1 then 1 else 0 end) AsthmaManagementPlanDeclined,

	Sum(Case when AsthmaPrevalence=1 and AsthmaReviewInLast12Months=1 then 1 else 0 end) AsthmaReviewInLast12Months,

	Sum(Case when AsthmaPrevalence=1 and AdjustedSmokingStatus='ActiveSmoker' then 1 else 0 end) AsthmaActiveSmoker,
	Sum(Case when AsthmaPrevalence=1 and AdjustedSmokingStatus='Non-Smoker' then 1 else 0 end) AsthmaNonSmoker,
	Sum(Case when AsthmaPrevalence=1 and AdjustedSmokingStatus='Ex-Smoker' then 1 else 0 end) AsthmaExSmoker,
	Sum(Case when AsthmaPrevalence=1 and AdjustedSmokingStatus='Unknown' then 1 else 0 end) AsthmaUnknownSmokerStatus,

	Sum(Case when Sex='M' then 1 else 0 end) PopulationMale,
	Sum(Case when Sex='F' then 1 else 0 end) PopulationFemale,
	Sum(Case when Age between 0 and 4 then 1 else 0 end) Population00to04,
	Sum(Case when Age between 5 and 15 then 1 else 0 end) Population05to15,
	Sum(Case when Age between 16 and 64 then 1 else 0 end) Population16to64,
	Sum(Case when Age>=65 then 1 else 0 end) Population65Plus,

	Sum(Case when AdjustedSmokingStatus='ActiveSmoker' then 1 else 0 end) PopulationActiveSmoker,
	Sum(Case when AdjustedSmokingStatus='Non-Smoker' then 1 else 0 end) PopulationNonSmoker,
	Sum(Case when AdjustedSmokingStatus='Ex-Smoker' then 1 else 0 end) PopulationExSmoker,

	Sum(Case when AsthmaPrevalence=1 and PneumoVaccine=1 and Age>=65 then 1 else 0 end) AsthmaPneumoVaccine65Plus,

	IsNull(Sum(InhaledRelievers),0) InhaledRelievers,
	IsNull(Sum(Preventers),0) Preventers,
	Max(InhalertoPreventerRatioSTDEVforNetworkIncludingPractice) InhalertoPreventerRatioSTDEVforNetworkIncludingPractice,
	Max(Case when iprrnstd.PracticeID is not null then InhalertoPreventerRatioRestofNetworkSTDEV end) InhalertoPreventerRatioSTDEVforNetworkExcludingPractice

from #AllAsthmaPatients aap
	left outer join #InhalertoPreventerRatioRestofNetworkSTDEV iprrnstd
		on aap.PracticeID = iprrnstd.PracticeID

Group by ISOYear,
	ISOWeek,
	ISOWeekStartDate,
	ISOWeekEndDate,
	aap.PracticeID

end 
