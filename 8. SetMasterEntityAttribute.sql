/************************************************************************
Procedure Name	:	MDM.SetMasterEntityAttribute
Objective		:	This procedure is used to save the master data for Entity Attribute
Database		:	GlobalMasterAttributes
Author			:	Pragya Sanjana
Creation Date	:	12th May 2020
Modified By		:
Modified Date	:
Execution Time	:	00.00
Input Parameters:	@jsonStringForEntityAttributes, @machineName, @loginUser

Algorithm and other details:
Test Run		:	"E:\NAVMDM\AttributeMaster\Docs\Execution Report - Insert (EntityAttributes).txt"
					"E:\NAVMDM\AttributeMaster\Docs\Execution Report - Update(EntityAttributes).txt"
*************************************************************************/
CREATE PROCEDURE MDM.SetMasterEntityAttribute
(
	@jsonStringForEntityAttributes	 NVARCHAR(MAX)  
	,@machineName					 NVARCHAR(60)
	,@loginUser						 NVARCHAR(60)
)

AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	BEGIN TRY

		--DECLARE VARIABLES
		DECLARE @lastModifiedDate	DATETIME2
		DECLARE @AttributeID INTEGER

		DECLARE @EntityAttributeMaster TABLE
		(
			AttributeMasterID			INTEGER				NOT NULL
			,AttributeID				INTEGER				NOT NULL
			,AttributeName				MDM.UDTLongName		NOT NULL	
			,AttributeCode				MDM.UDTShortName
			,AttributeValue				MDM.UDTLongName
			,IsActive					TINYINT				NOT NULL
			,IsDeleted					TINYINT				NOT NULL
			,IsRTAAttribute				TINYINT				NOT NULL
			,ControlType				INTEGER
			,Action						CHAR(1)				NOT NULL
		)	
		DECLARE @EntityAttributeMasterMapping TABLE
		(
			AttributeMasterID			INTEGER				NOT NULL	
			,EntityType					INTEGER				NOT NULL
			,IsDefaultValue				TINYINT				NOT NULL
			,IsPartOfDefaultSet			TINYINT				
			,DisplayOrder				TINYINT				
			,IsMandatory				TINYINT			    
			,IsValidateFASLockDate		BIT					NOT NULL
			,Action						CHAR(1)				NOT NULL
		)
		DECLARE @resultSet TABLE
		(
			ID					INTEGER IDENTITY(1,1)
			,AttributeMasterID	INTEGER
		)
		DECLARE @oldAttributeMasterIDs TABLE
		(
			ID					INTEGER IDENTITY(1,1)
			,oldAttributeMasterID	INTEGER		
		)
		
		--Update last modified date
		SET @lastModifiedDate = GETDATE()

		--READ DATA FROM JSON AND INSERT IT INTO TEMP TABLE
		IF (@jsonStringForEntityAttributes IS NOT NULL)
		BEGIN

			INSERT INTO @EntityAttributeMaster(	
												AttributeMasterID														
												,AttributeID
												,AttributeName			
												,AttributeCode			
												,AttributeValue			
												,IsActive				
												,IsDeleted				
												,IsRTAAttribute			
												,ControlType			
												,Action				
											  )
										SELECT	AttributeMasterID	
												,AttributeID
												,AttributeName			
												,AttributeCode			
												,AttributeValue			
												,IsActive				
												,IsDeleted				
												,IsRTAAttribute			
												,ControlType			
												,Action					
										FROM	OPENJSON(@jsonStringForEntityAttributes, '$.AttributeMaster')   
										WITH  (	
												AttributeMasterID			INTEGER		
												,AttributeID				INTEGER
												,AttributeName				MDM.UDTLongName	
												,AttributeCode				MDM.UDTShortName
												,AttributeValue				MDM.UDTLongName
												,IsActive					TINYINT			
												,IsDeleted					TINYINT			
												,IsRTAAttribute				TINYINT			
												,ControlType				INTEGER		
												,Action						CHAR(1)			
											 )

			INSERT INTO @EntityAttributeMasterMapping(
														AttributeMasterID		
														,EntityType				
														,IsDefaultValue			
														,IsPartOfDefaultSet		
														,DisplayOrder			
														,IsMandatory			
														,IsValidateFASLockDate
														,Action
													 )
												SELECT	AttributeMasterID		
														,EntityType				
														,IsDefaultValue			
														,IsPartOfDefaultSet		
														,DisplayOrder			
														,IsMandatory			
														,IsValidateFASLockDate
														,Action
												FROM OPENJSON(@jsonStringForEntityAttributes, '$.AttributeMasterMapping')
												WITH(
														AttributeMasterID			INTEGER	
														,EntityType					INTEGER	
														,IsDefaultValue				TINYINT	
														,IsPartOfDefaultSet			TINYINT	
														,DisplayOrder				TINYINT	
														,IsMandatory				TINYINT	
														,IsValidateFASLockDate		BIT		
														,Action						CHAR(1)
													)
		END

		--Insert AttributeMasterID of JSON into the @oldAttributeMasterIDs
		INSERT INTO @oldAttributeMasterIDs(oldAttributeMasterID)
		SELECT DISTINCT AttributeMasterID FROM @EntityAttributeMaster

		--Set AttributeID for new Attribute
		SELECT	@AttributeID = NEXT VALUE FOR MDM.AttributeID 
		UPDATE A
			SET A.AttributeID = @AttributeID
		FROM @EntityAttributeMaster A
		WHERE Action = 'I'
		AND	A.AttributeID = 0

		BEGIN TRANSACTION
			--Update Data into MDM.EntityAttributeMaster Table when Action is 'U'
			UPDATE A
				SET   A.AttributeName				=		B.AttributeName			
					  ,A.AttributeCode				=		B.AttributeCode			
					  ,A.AttributeValue				=		B.AttributeValue			
					  ,A.IsActive					=		B.IsActive				
					  ,A.IsDeleted					=		B.IsDeleted				
					  ,A.IsRTAAttribute				=		B.IsRTAAttribute			
					  ,A.ControlType				=		B.ControlType			
					  ,A.ReviewedBy					=		@loginUser				
					  ,A.LastModifiedDate			=		@lastModifiedDate	
					  ,A.LastModifiedByUser			=		@loginUser	
					  ,A.LastModifiedByMachine		=		@machineName
			FROM MDM.EntityAttributesMaster A
			INNER JOIN
				@EntityAttributeMaster B
				ON A.AttributeMasterID = B.AttributeMasterID
			WHERE B.Action = 'U'

			--Update Data into MDM.EntityAttributeMasterMapping Table when Action is 'U'
			UPDATE A
				SET	 A.EntityType					=		B.EntityType				
					,A.IsDefaultValue				=		B.IsDefaultValue			
					,A.IsPartOfDefaultSet			=		B.IsPartOfDefaultSet		
					,A.DisplayOrder					=		B.DisplayOrder			
					,A.IsMandatory					=		B.IsMandatory			
					,A.IsValidateFASLockDate		=		B.IsValidateFASLockDate
			FROM MDM.EntityAttributesMasterMapping A  
			INNER JOIN
				@EntityAttributeMasterMapping B
				ON A.AttributeMasterID = B.AttributeMasterID
			WHERE B.Action = 'U'

			--Insert Data into MDM.EntityAttributeMaster Table when Action is 'I'
			INSERT INTO MDM.EntityAttributesMaster(
													AttributeID			
													,AttributeName			
													,AttributeCode			
													,AttributeValue			
													,IsActive				
													,IsDeleted				
													,IsRTAAttribute			
													,ControlType			
													,ReviewedBy				
													,LastModifiedDate		
													,LastModifiedByUser		
													,LastModifiedByMachine	
												  )
								OUTPUT inserted.AttributeMasterID
								INTO @resultSet (AttributeMasterID)
										  SELECT	AttributeID			
													,AttributeName			
													,AttributeCode			
													,AttributeValue			
													,IsActive				
													,IsDeleted				
													,IsRTAAttribute			
													,ControlType			
													,@loginUser		
													,@lastModifiedDate
													,@loginUser	
													,@machineName	
										  FROM @EntityAttributeMaster EAM
										  WHERE EAM.Action = 'I'

			--Insert Data into MDM.EntityAttributesMasterMapping Table when Action is 'I'					
			INSERT INTO MDM.EntityAttributesMasterMapping(
															AttributeMasterID		
															,EntityType				
															,IsDefaultValue			
															,IsPartOfDefaultSet		
															,DisplayOrder			
															,IsMandatory			
															,IsValidateFASLockDate
														 )
												SELECT		r.AttributeMasterID		
															,EAMM.EntityType				
															,EAMM.IsDefaultValue			
															,EAMM.IsPartOfDefaultSet		
															,EAMM.DisplayOrder			
															,EAMM.IsMandatory			
															,EAMM.IsValidateFASLockDate
												FROM @EntityAttributeMasterMapping EAMM
												INNER JOIN @oldAttributeMasterIDs A
													ON A.oldAttributeMasterID = EAMM.AttributeMasterID
												INNER JOIN @resultSet R
													ON R.ID = A.ID
												WHERE EAMM.Action = 'I'

		COMMIT TRANSACTION
		RETURN 0
	
	END TRY
	BEGIN CATCH
		IF(XACT_STATE() != 0 OR @@TRANCOUNT > 0)
		ROLLBACK TRANSACTION
		--EXEC MDM.RethrowError
		RETURN -1
	END CATCH
END


