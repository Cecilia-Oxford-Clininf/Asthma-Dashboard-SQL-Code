use RCGP_Differential
go

declare @Start datetime  = getdate();
declare @msg nvarchar(max)

--create table RCGP_Dashboard.Asthma.PatientIndicatorNew (
--	PracticeID varchar(6) not null,
--	PseudoID int not null,
--	IndicatorDate date not null,
--	AgeAtIndicatorDate tinyint not null,
--	CategoryorDrugName varchar(50) not null,
--		Constraint PK_RCGP_Dashboard_AsthmaPI_New_PracticeID_PseudoID_IndicatorDate_CategoryorDrugName
--			primary key (PracticeID, PseudoID, IndicatorDate, CategoryorDrugName),
--	CategoryOrDrugType varchar(1) not null,
--	BulkorDifferential varchar(12) null,
--	LatestISOYearAndWeek int not null
--)


set @msg = N'Getting Condition Flat List ' + convert(nvarchar(30), getdate(), 120)
raiserror (@msg, 0, 1) with nowait
set @start = getdate();

	drop table if exists #Conditions

create table #Conditions (
	ConditionID smallint not null primary key
	)

insert #Conditions
(ConditionID)
Select 
	Distinct
	cl.ConditionID
from GPCoding.CodeLibrary.ConditionList cl
		
where cl.ConditionID in (
1007, --UpperRespiratoryInfection-WRpt --for the annual dataset
1020, --Influenza-likeIllness-WRpt --for the annual dataset
1055, --LowerRespiratoryTractInfection-WRpt --for the annual dataset
4204, --AsthmaExacerbation
4208, --AsthmaReview
4209, --AsthmaManagementPlan
4210, --AsthmaManagementNoPlan
7163, --HospitalAdmission
7183  --SeenInHospitalCasualty
)

set @msg = N'Saving a copy of the ECL ' + convert(nvarchar(30), getdate(), 120)
raiserror (@msg, 0, 1) with nowait
set @start = getdate();

	drop table if exists RCGP_Dashboard.Asthma.ECL
Create table RCGP_Dashboard.Asthma.ECL
(	ConditionID smallint not null,
	ConditionName varchar(50) not null,
	ECLElement varchar(20) not null,
	ConceptID bigint not null
		Constraint PK_Asthma_ECL_ConditionID_ECLElement_ConceptID
			primary key (ConditionID,ECLElement,ConceptID)
)

Insert RCGP_Dashboard.Asthma.ECL

Select
	ac.ConditionID,
	cl.ConditionName,
	ecl.ECLElement,
	ecl.ConceptID

from #Conditions ac
	inner join GPCoding.CodeLibrary.ConditionList cl
		on ac.ConditionID = cl.ConditionID
	inner join GPCoding.CodeLibrary.ECLMasters ecl
		on ac.ConditionID = ecl.ConditionID

set @msg = N'Expanding Flat List from the ECL ' + convert(nvarchar(30), getdate(), 120)
raiserror (@msg, 0, 1) with nowait
set @start = getdate();

--Make sure this table is empty before you start
	drop table if exists #AllResults

create table #AllResults (
	ConditionID smallint not null,
	ConceptID bigint not null,
		primary key (ConditionID, ConceptID))

exec GPCoding.CodeLibrary.GenerateFlatListFromECLMasters

--Here are the results - do with them what you will!

	drop table if exists RCGP_Dashboard.Asthma.FlatList_SNOMED_CT

Create table RCGP_Dashboard.Asthma.FlatList_SNOMED_CT
(	ConditionName varchar(50) not null,
	ConditionID smallint not null,
	ConceptID bigint not null
		Constraint PK_Asthma_FlatList_ConditionName_ConceptID
			primary key (ConditionName,ConceptID),
	PrimaryTerm varchar(255) not null
)
insert RCGP_Dashboard.Asthma.FlatList_SNOMED_CT

Select 
	cl.ConditionName,
	cl.ConditionID,
	ar.ConceptID,
	isnull(pt.term,syn.[EMIS national term]) PrimaryTerm

from #AllResults ar
	inner join GPCoding.CodeLibrary.ConditionList cl
		on ar.ConditionID = cl.ConditionID
	left outer join GPCoding.SNOMEDCT.SCT_CONCEPT_PT pt
		on ar.ConceptID = pt.id
	left outer join GPCoding.dbo.EmisNationalCode_Syn syn
		on ar.ConceptID = syn.SnomedConceptID

go

declare @Start datetime  = getdate();
declare @msg nvarchar(max)

Set @msg = N'Getting EMIS Drug List ' + convert(nvarchar(30), getdate(), 120)
raiserror (@msg, 0, 1) with nowait
set @start = getdate();

drop table if exists RCGP_Dashboard.Asthma.FlatList_EMISDrugs

Create table RCGP_Dashboard.Asthma.FlatList_EMISDrugs
(	ConditionName varchar(50) not null,
	ConditionID smallint not null,
	EMISCode varchar(20) collate Latin1_General_CS_AS not null,
	EMISDescription varchar(255) not null,
		Constraint PK_Asthma_EMIS_Drugs
			primary key (ConditionID, EMISCode)
)
Insert RCGP_Dashboard.Asthma.FlatList_EMISDrugs

Select
	Distinct
	cl.ConditionName,
	mpf.ConditionID,
	mpf.PreparationCode EMISCode,
	mpf.PreparationDescription EMISDescription

from GPCoding.JohnW.MentorPrepFlats mpf
	inner join GPCoding.CodeLibrary.ConditionList cl
		on cl.ConditionID = mpf.ConditionId

where mpf.ConditionID in (	
	 5119, --CorticosteroidsInhaled
	 5153, --Antimuscarinics
	 5154, --Beta2AdrenoceptorAgonistsSelective
	 5267  --Prednisolone
	)
go

declare @Start datetime  = getdate();
declare @msg nvarchar(max)

set @msg = N'Getting DM+D Drug List ' + convert(nvarchar(30), getdate(), 120)
raiserror (@msg, 0, 1) with nowait
set @start = getdate();

--N.B. the temporary table names must be fixed as #Conditions and #AllResults
--otherwise the stored procedure won't work!

--Fill this table with the conditions you're interested in

drop table if exists #Conditions
create table #Conditions (
	ConditionID smallint not null primary key
	)

Insert #Conditions

Select 
	Distinct
	cl.ConditionID
from GPCoding.CodeLibrary.ConditionList cl

where cl.ConditionID in (
5119, --CorticosteroidsInhaled
5153, --Antimuscarinics
5267, --Prednisolone
5154  --Beta2AdrenoceptorAgonistsSelective																												
)

--Make sure this table is empty before you start
drop table if exists #AllResults
go
create table #AllResults (
	ConditionID smallint not null,
	ProductID bigint not null,
	primary key (ConditionID, ProductID))

exec GPCoding.CodeLibrary.GenerateDrugFlatListFromIngredientMasters

--Here are the results - do with them what you will!

drop table if exists RCGP_Dashboard.Asthma.FlatList_DMD

Create table RCGP_Dashboard.Asthma.FlatList_DMD
(	ConditionID smallint not null,
	ConditionName varchar(50) not null,
	DMD_Code bigint not null,
	PrimaryTerm varchar(255) not null 
		Constraint PK_Asthma_ConditionID_DMD_Code
			primary key (ConditionID,DMD_Code)
)

Insert RCGP_Dashboard.Asthma.FlatList_DMD

Select cl.ConditionID,
	   cl.ConditionName,
	   ar.ProductID,	
	   Isnull(pt.term,syn.[EMIS national term]) as PrimaryTerm
from #AllResults ar
	inner join  GPCoding.CodeLibrary.ConditionList cl
		on cl.ConditionID = ar.ConditionID
	left outer join GPCoding.SNOMEDCT.SCT_CONCEPT_PT pt
		on pt.id = ar.ProductID
	left outer join GPCoding.dbo.EMISNationalCode_Syn syn
		on pt.id is null
		and syn.SnomedConceptID = ar.ProductID



declare @time varchar(30)
declare @DifferentialLatestWeek int

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

if object_id('tempdb..#PracticeDataSource') is not null
	drop table #PracticeDataSource

create table #PracticeDataSource (
	DataSource varchar(100) not null,
	PracticeID varchar(6) not null,
	primary key (DataSource,PracticeID)
)

insert #PracticeDataSource
select distinct DataSource,
	PracticeID
from PracticeUsage

--from the 2019 calendar year until all future weeks as requested by Edinburgh CTU colleagues:
declare @StudyStartDate date = '2019-01-01'
declare @DataSource varchar(100) = ''
declare @DataSourceType varchar(100)
declare @ISOYearAndWeek int
declare @sql nvarchar(max)
declare @param nvarchar(max) = N'@DataSource varchar(100), @DataSourceType varchar(100), @ISOYearAndWeek int, @StudyStartDate date'

while 1 = 1
begin
	--It doesn't matter what order we do it in, so do it in the simplest
	--alphabetical order rather than most recent or oldest first.
	select top 1 @DataSource = BulkDataSource,
		@DataSourceType = 'Bulk',
		@ISOYearAndWeek = ISOYearAndWeek
	from BulkDatabase
	where BulkDataSource > @DataSource
	order by BulkDataSource

	if @@rowcount = 0
	begin
		set @DataSource = 'RCGP_Differential'
		set @DataSourceType = 'Differential'
		set @ISOYearAndWeek = @DifferentialLatestWeek
	end

	set @time = convert(varchar(30), getdate(),114)
	raiserror ('Checking Asthma events data for data source %s at %s',0,1, @DataSource, @time) with nowait

	if not exists (select *
					from RCGP_Dashboard.Asthma.PatientIndicatorNew api
					where api.BulkorDifferential = @DataSourceType
					and api.LatestISOYearAndWeek = @ISOYearAndWeek)
	begin
		set @time = convert(varchar(30), getdate(),114)
		raiserror ('Starting Asthma events data for data source %s at %s',0,1, @DataSource, @time) with nowait

		set @sql = N'insert RCGP_Dashboard.Asthma.PatientIndicatorNew

		Select ev.PracticeID,
			ev.PseudoID,
			ev.EventDate,
			Min(ev.AgeAtEvent),
			snomed.ConditionName Category,
			''C'',
			@DataSourceType, 
			@ISOYearAndWeek 

		from ' + @DataSource + N'.dbo.EventWithCodingSystemAndExtractDate ev
		inner join RCGP_Dashboard.Asthma.FlatList_SNOMED_CT snomed
			on ev.SnomedConceptID = snomed.ConceptID
		inner join #PracticeDataSource pu
			on pu.DataSource = @DataSource
			and pu.PracticeID = ev.PracticeID
		where ev.AgeAtEvent >= 0
		and ev.AgeAtEvent <= 120
		and ev.SnomedConceptID <> ''''
		and ev.EventDate <= ev.ExtractDate
		and ev.EventDate>=DateAdd(Year,-1,@StudyStartDate)
		
		Group by ev.PracticeID,
			ev.PseudoID,
			ev.EventDate,
			snomed.ConditionName
			
		having not exists (select *
					from RCGP_Dashboard.Asthma.PatientIndicatorNew api
					where api.PracticeID = ev.PracticeID 
					and api.PseudoID = ev.PseudoID 
					and api.CategoryorDrugName = snomed.ConditionName
					and api.IndicatorDate = ev.EventDate)'
	------Removed as need to also search for duplicates when looping through the bulks, otherwise there'll be a primary key violation...
		--if @DataSourceType = 'Differential'
		--begin
		--	set @sql += N'
		--	having not exists (select *
		--			from RCGP_Dashboard.Asthma.PatientIndicatorNew api
		--			where api.PracticeID = ev.PracticeID 
		--			and api.PseudoID = ev.PseudoID 
		--			and api.CategoryorDrugName = d.Category
		--			and api.IndicatorDate = ev.EventDate)'
		--end

		exec sp_executesql @sql,@param,@DataSource,@DataSourceType,@ISOYearAndWeek,@StudyStartDate

		set @time = convert(varchar(30), getdate(),114)
		raiserror ('Loaded events data source %s at %s',0,1, @DataSource, @time) with nowait
	end

	set @time = convert(varchar(30), getdate(),114)
	raiserror ('Checking EMIS prednisolone data for data source %s at %s',0,1, @DataSource, @time) with nowait

	if not exists (select *
					from RCGP_Dashboard.Asthma.PatientIndicatorNew dpi
					where dpi.BulkorDifferential = @DataSourceType
					and dpi.LatestISOYearAndWeek = @ISOYearAndWeek
					and dpi.CategoryOrDrugType='D')
	begin
		set @time = convert(varchar(30), getdate(),114)
		raiserror ('Starting EMIS prednisolone data for data source %s at %s',0,1, @DataSource, @time) with nowait

--------Need to introduce a priority order for each drug code as some sit in more than one group.
-----At this stage just going to base this on alphabetical

		set @sql = N'insert RCGP_Dashboard.Asthma.PatientIndicatorNew

		Select
			p.PracticeID,
			p.PseudoID,
			p.IssueDate,
			Min(p.AgeAtIssueDate),
			ec.ConditionName DrugCategory,
			''D'',
			@DataSourceType, 
		@ISOYearAndWeek

		from ' + @DataSource + N'.dbo.PrescriptionWithExtractDate p
		inner join #PracticeDataSource pu
				on pu.DataSource = @DataSource
				and pu.PracticeID = p.PracticeID
		inner join RCGP_Dashboard.Asthma.FlatList_EMISDrugs ec
				on p.EMISCode = ec.EMISCode collate Latin1_General_CS_AS 

		where ec.ConditionID = 5267
			and p.IssueType <> ''R''
			and p.AgeAtIssueDate >= 0
			and p.AgeAtIssueDate <= 120
			and p.EMISCode <> ''''
			and p.ClinicalSystem = ''EMIS Web'' 
			and p.IssueDate <= p.ExtractDate
			and p.IssueDate >= @StudyStartDate
		
		group by p.PracticeID,
			p.PseudoID,
			p.IssueDate,
			ec.ConditionName
			
		Having not exists (select *
					from RCGP_Dashboard.Asthma.PatientIndicatorNew api
					where api.PracticeID = p.PracticeID 
					and api.PseudoID = p.PseudoID
					and api.IndicatorDate = p.IssueDate
					and api.CategoryorDrugName = ec.ConditionName)'
		
	------Removed as need to also search for duplicates when looping through the bulks, otherwise there'll be a primary key violation...
	--if @DataSourceType = 'Differential'
	--	begin
	--		set @sql += N'
	--		Having not exists (select *
	--				from RCGP_Dashboard.Asthma.PatientIndicatorNew api
	--				where api.PracticeID = p.PracticeID 
	--				and api.PseudoID = p.PseudoID
	--				and api.IndicatorDate = p.IssueDate
	--				and api.CategoryorDrugName = ec.DrugCategory)'
	--	end

		exec sp_executesql @sql,@param,@DataSource,@DataSourceType,@ISOYearAndWeek,@StudyStartDate

		set @time = convert(varchar(30), getdate(),114)
		raiserror ('Loaded EMIS prednisolone data for data source %s at %s',0,1, @DataSource, @time) with nowait
	end

	set @time = convert(varchar(30), getdate(),114)
	raiserror ('Checking DM+D prednisolone data for data source %s at %s',0,1, @DataSource, @time) with nowait

	begin
		set @time = convert(varchar(30), getdate(),114)
		raiserror ('Starting DM+D prednisolone data for data source %s at %s',0,1, @DataSource, @time) with nowait

		set @sql = N'insert RCGP_Dashboard.Asthma.PatientIndicatorNew

		Select
			p.PracticeID,
			p.PseudoID,
			p.IssueDate,
			Min(p.AgeAtIssueDate),
			ec.ConditionName DrugCategory,
			''D'',
			@DataSourceType, 
		@ISOYearAndWeek

		from ' + @DataSource + N'.dbo.PrescriptionWithExtractDate p
		inner join #PracticeDataSource pu
				on pu.DataSource = @DataSource
				and pu.PracticeID = p.PracticeID
		inner join RCGP_Dashboard.Asthma.FlatList_DMD ec
				on Try_convert(bigint,p.DMDCode) = Try_convert(bigint,ec.DMD_Code) 

		where ec.ConditionID = 5267
			and p.IssueType <> ''R''
			and p.AgeAtIssueDate >= 0
			and p.AgeAtIssueDate <= 120
			and p.DMDCode <> ''''
			and p.IssueDate <= p.ExtractDate
			and p.IssueDate >= @StudyStartDate

		group by p.PracticeID,
			p.PseudoID,
			p.IssueDate,
			ec.ConditionName
			
		Having not exists (select *
					from RCGP_Dashboard.Asthma.PatientIndicatorNew api
					where api.PracticeID = p.PracticeID 
					and api.PseudoID = p.PseudoID
					and api.IndicatorDate = p.IssueDate
					and api.CategoryorDrugName = ec.ConditionName)'
		
	------Removed as need to also search for duplicates when looping through the bulks, otherwise there'll be a primary key violation...
	--if @DataSourceType = 'Differential'
	--	begin
	--		set @sql += N'
	--		Having not exists (select *
	--				from RCGP_Dashboard.Asthma.PatientIndicatorNew api
	--				where api.PracticeID = p.PracticeID 
	--				and api.PseudoID = p.PseudoID
	--				and api.IndicatorDate = p.IssueDate
	--				and api.CategoryorDrugName = ec.DrugCategory)'
	--	end

		exec sp_executesql @sql,@param,@DataSource,@DataSourceType,@ISOYearAndWeek,@StudyStartDate

		set @time = convert(varchar(30), getdate(),114)
		raiserror ('Loaded DM+D  prednisolone data for data source %s at %s',0,1, @DataSource, @time) with nowait
	end	

	set @time = convert(varchar(30), getdate(),114)
	raiserror ('Checking EMIS drug data for data source %s at %s',0,1, @DataSource, @time) with nowait

	if not exists (select *
					from RCGP_Dashboard.Asthma.PatientIndicatorNew dpi
					where dpi.BulkorDifferential = @DataSourceType
					and dpi.LatestISOYearAndWeek = @ISOYearAndWeek
					and dpi.CategoryOrDrugType='D')
	begin
		set @time = convert(varchar(30), getdate(),114)
		raiserror ('Starting EMIS Drug data for data source %s at %s',0,1, @DataSource, @time) with nowait

--------Need to introduce a priority order for each drug code as some sit in more than one group.
-----At this stage just going to base this on alphabetical

		set @sql = N'insert RCGP_Dashboard.Asthma.PatientIndicatorNew

		Select
			p.PracticeID,
			p.PseudoID,
			p.IssueDate,
			Min(p.AgeAtIssueDate),
			ec.ConditionName DrugCategory,
			''D'',
			@DataSourceType, 
		@ISOYearAndWeek

		from ' + @DataSource + N'.dbo.PrescriptionWithExtractDate p
		inner join #PracticeDataSource pu
				on pu.DataSource = @DataSource
				and pu.PracticeID = p.PracticeID
		inner join RCGP_Dashboard.Asthma.FlatList_EMISDrugs ec
				on p.EMISCode = ec.EMISCode collate Latin1_General_CS_AS 

		where ec.ConditionID <> 5267
			and p.AgeAtIssueDate >= 0
			and p.AgeAtIssueDate <= 120
			and p.EMISCode <> ''''
			and p.ClinicalSystem = ''EMIS Web'' 
			and p.IssueDate <= p.ExtractDate
			and p.IssueDate >= @StudyStartDate
		
		group by p.PracticeID,
			p.PseudoID,
			p.IssueDate,
			ec.ConditionName
			
		Having not exists (select *
					from RCGP_Dashboard.Asthma.PatientIndicatorNew api
					where api.PracticeID = p.PracticeID 
					and api.PseudoID = p.PseudoID
					and api.IndicatorDate = p.IssueDate
					and api.CategoryorDrugName = ec.ConditionName)'
		
	------Removed as need to also search for duplicates when looping through the bulks, otherwise there'll be a primary key violation...
	--if @DataSourceType = 'Differential'
	--	begin
	--		set @sql += N'
	--		Having not exists (select *
	--				from RCGP_Dashboard.Asthma.PatientIndicatorNew api
	--				where api.PracticeID = p.PracticeID 
	--				and api.PseudoID = p.PseudoID
	--				and api.IndicatorDate = p.IssueDate
	--				and api.CategoryorDrugName = ec.DrugCategory)'
	--	end

		exec sp_executesql @sql,@param,@DataSource,@DataSourceType,@ISOYearAndWeek,@StudyStartDate

		set @time = convert(varchar(30), getdate(),114)
		raiserror ('Loaded EMIS drug data for data source %s at %s',0,1, @DataSource, @time) with nowait
	end

	set @time = convert(varchar(30), getdate(),114)
	raiserror ('Checking DM+D drug data for data source %s at %s',0,1, @DataSource, @time) with nowait

	begin
		set @time = convert(varchar(30), getdate(),114)
		raiserror ('Starting DM+D Drug data for data source %s at %s',0,1, @DataSource, @time) with nowait

		set @sql = N'insert RCGP_Dashboard.Asthma.PatientIndicatorNew

		Select
			p.PracticeID,
			p.PseudoID,
			p.IssueDate,
			Min(p.AgeAtIssueDate),
			ec.ConditionName DrugCategory,
			''D'',
			@DataSourceType, 
		@ISOYearAndWeek

		from ' + @DataSource + N'.dbo.PrescriptionWithExtractDate p
		inner join #PracticeDataSource pu
				on pu.DataSource = @DataSource
				and pu.PracticeID = p.PracticeID
		inner join RCGP_Dashboard.Asthma.FlatList_DMD ec
				on Try_convert(bigint,p.DMDCode) = Try_convert(bigint,ec.DMD_Code) 

		where ec.ConditionID <> 5267
			and p.AgeAtIssueDate >= 0
			and p.AgeAtIssueDate <= 120
			and p.DMDCode <> ''''
			and p.IssueDate <= p.ExtractDate
			and p.IssueDate >= @StudyStartDate

		group by p.PracticeID,
			p.PseudoID,
			p.IssueDate,
			ec.ConditionName
			
		Having not exists (select *
					from RCGP_Dashboard.Asthma.PatientIndicatorNew api
					where api.PracticeID = p.PracticeID 
					and api.PseudoID = p.PseudoID
					and api.IndicatorDate = p.IssueDate
					and api.CategoryorDrugName = ec.ConditionName)'
		
	------Removed as need to also search for duplicates when looping through the bulks, otherwise there'll be a primary key violation...
	--if @DataSourceType = 'Differential'
	--	begin
	--		set @sql += N'
	--		Having not exists (select *
	--				from RCGP_Dashboard.Asthma.PatientIndicatorNew api
	--				where api.PracticeID = p.PracticeID 
	--				and api.PseudoID = p.PseudoID
	--				and api.IndicatorDate = p.IssueDate
	--				and api.CategoryorDrugName = ec.DrugCategory)'
	--	end

		exec sp_executesql @sql,@param,@DataSource,@DataSourceType,@ISOYearAndWeek,@StudyStartDate

		set @time = convert(varchar(30), getdate(),114)
		raiserror ('Loaded DM+D drug data for data source %s at %s',0,1, @DataSource, @time) with nowait
	end
	
	if @DataSourceType = 'Differential'
		break
end

set @time = convert(varchar(30), getdate(),114)
raiserror ('Updating latest week differential data %s',0,1, @time) with nowait
	
update RCGP_Dashboard.Asthma.PatientIndicatorNew
set LatestISOYearAndWeek = @DifferentialLatestWeek
where BulkorDifferential = 'Differential'
and LatestISOYearAndWeek <> @DifferentialLatestWeek

set @time = convert(varchar(30), getdate(),114)
raiserror ('Updated latest week differential data %s',0,1, @time) with nowait


--set @msg = N'Creating non-clustered index on patient indicator table from the dashboard ' + convert(nvarchar(30), getdate(), 120)
--raiserror (@msg, 0, 1) with nowait
--set @start = getdate();

--drop index IX_Projects_Asthma_EventsAndPrescriptions_PracticeID_PseudoID_IndicatorDate_CategoryorDrugName
--create nonclustered index IX_Projects_Asthma_EventsAndPrescriptions_PracticeID_PseudoID_IndicatorDate_CategoryorDrugName
--on [RCGP_Dashboard].[Asthma].[PatientIndicatorNew]

--(	PracticeID,
--	PseudoID,
--	IndicatorDate,
--	CategoryorDrugName	
--)