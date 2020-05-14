/************************************************************************
Procedure Name	:	MDM.SetMasterClientAttribute
Objective		:	This procedure is used to save the master data for Client Attribute
Database		:	GlobalMasterAttributes
Author			:	Pragya Sanjana
Creation Date	:	13th May 2020
Modified By		:
Modified Date	:
Execution Time	:	00.00
Input Parameters:	@jsonStringForClientAttributes, @machineName, @loginUser

Algorithm and other details:
Test Run		:	"E:\NAVMDM\AttributeMaster\Docs\Execution Report - Insert (ClientAttributes).txt"
					"E:\NAVMDM\AttributeMaster\Docs\Execution Report - Update(ClientAttributes).txt"
*************************************************************************/
CREATE PROCEDURE MDM.SetMasterClientAttribute
(
	@jsonStringForClientAttributes		NVARCHAR(MAX)
	,@machineName						NVARCHAR(60)
	,@loginUser							NVARCHAR(60)
)

AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	BEGIN TRY

		--DECLARE VARIABLES
		DECLARE @lastModifiedDate	DATETIME2
		DECLARE @AttributeID INTEGER

		DECLARE @ClientAttributeMaster TABLE
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
		DECLARE @ClientAttributeMasterMapping TABLE
		(
			AttributeMasterID			INTEGER				NOT NULL	
			,ClientType					INTEGER				NOT NULL
			,IsDefaultValue				TINYINT				NOT NULL
			,IsPartOfDefaultSet			TINYINT				NOT NULL
			,DisplayOrder				TINYINT				NOT NULL
			,IsMandatory				TINYINT			    NOT NULL
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
		IF (@jsonStringForClientAttributes IS NOT NULL)
		BEGIN

			INSERT INTO @ClientAttributeMaster(	
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
										FROM	OPENJSON(@jsonStringForClientAttributes, '$.AttributeMaster')   
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

			INSERT INTO @ClientAttributeMasterMapping(
														AttributeMasterID		
														,ClientType				
														,IsDefaultValue			
														,IsPartOfDefaultSet		
														,DisplayOrder			
														,IsMandatory		
														,Action
													 )
												SELECT	AttributeMasterID		
														,ClientType				
														,IsDefaultValue			
														,IsPartOfDefaultSet		
														,DisplayOrder			
														,IsMandatory		
														,Action
												FROM OPENJSON(@jsonStringForClientAttributes, '$.AttributeMasterMapping')
												WITH(
														AttributeMasterID			INTEGER	
														,ClientType					INTEGER	
														,IsDefaultValue				TINYINT	
														,IsPartOfDefaultSet			TINYINT	
														,DisplayOrder				TINYINT	
														,IsMandatory				TINYINT		
														,Action						CHAR(1)
													)
		END

		--Insert AttributeMasterID of JSON into the @oldAttributeMasterIDs
		INSERT INTO @oldAttributeMasterIDs(oldAttributeMasterID)
		SELECT DISTINCT AttributeMasterID FROM @ClientAttributeMaster

		--Set AttributeID for new Attribute
		SELECT	@AttributeID = NEXT VALUE FOR MDM.AttributeID 
		UPDATE A
			SET A.AttributeID = @AttributeID
		FROM @ClientAttributeMaster A
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
				@ClientAttributeMaster B
				ON A.AttributeMasterID = B.AttributeMasterID
			WHERE B.Action = 'U'

			--Update Data into MDM.EntityAttributeMasterMapping Table when Action is 'U'
			UPDATE A
				SET	 A.ClientType					=		B.ClientType				
					,A.IsDefaultValue				=		B.IsDefaultValue			
					,A.IsPartOfDefaultSet			=		B.IsPartOfDefaultSet		
					,A.DisplayOrder					=		B.DisplayOrder			
					,A.IsMandatory					=		B.IsMandatory			
			FROM MDM.ClientAttributeMasterMapping A  
			INNER JOIN
				@ClientAttributeMasterMapping B
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
										  FROM @ClientAttributeMaster CAM
										  WHERE CAM.Action = 'I'

			--Insert Data into MDM.EntityAttributesMasterMapping Table when Action is 'I'					
			INSERT INTO MDM.ClientAttributeMasterMapping(
															AttributeMasterID		
															,ClientType				
															,IsDefaultValue			
															,IsPartOfDefaultSet		
															,DisplayOrder			
															,IsMandatory			
														 )
												SELECT		r.AttributeMasterID		
															,CAMM.ClientType				
															,CAMM.IsDefaultValue			
															,CAMM.IsPartOfDefaultSet		
															,CAMM.DisplayOrder			
															,CAMM.IsMandatory			
												FROM @ClientAttributeMasterMapping CAMM
												INNER JOIN @oldAttributeMasterIDs A
													ON A.oldAttributeMasterID = CAMM.AttributeMasterID
												INNER JOIN @resultSet R
													ON R.ID = A.ID
												WHERE CAMM.Action = 'I'

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


