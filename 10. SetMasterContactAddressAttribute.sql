/************************************************************************
Procedure Name	:	MDM.SetMasterContactAddressAttribute
Objective		:	This procedure is used to save the master data for Contact/Address Attribute
Database		:	GlobalMasterAttributes
Author			:	Pragya Sanjana
Creation Date	:	13th May 2020
Modified By		:
Modified Date	:
Execution Time	:	00.00
Input Parameters:	@jsonStringForContactAddressAttributes, @machineName, @loginUser

Algorithm and other details:
Test Run		:	"E:\NAVMDM\AttributeMaster\Docs\Execution Report - Insert (ContactAddressAttributes).txt"
					"E:\NAVMDM\AttributeMaster\Docs\Execution Report - Update(ContactAddressAttributes).txt"
*************************************************************************/
CREATE PROCEDURE MDM.SetMasterContactAddressAttribute
(
	@jsonStringForContactAddressAttributes		NVARCHAR(MAX)
	,@machineName								NVARCHAR(60)
	,@loginUser									NVARCHAR(60)
)

AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	BEGIN TRY

		--DECLARE VARIABLES
		DECLARE @lastModifiedDate	DATETIME2
		DECLARE @AttributeID INTEGER

		DECLARE @ContactAddressAttributeMaster TABLE
		(
			AttributeID					INTEGER				NOT NULL
			,AttributeName				MDM.UDTLongName		NOT NULL
			,IsActive					TINYINT				NOT NULL
			,IsDeleted					TINYINT				NOT NULL
			,ControlType				INTEGER				
			,IsMandatory				TINYINT				
			,IsAddressType				TINYINT				NOT NULL
			,Action						CHAR(1)
		)

		DECLARE @ContactAttributeMasterValues TABLE
		(
			AttributeMasterValueID		INTEGER				NOT NULL
			,AttributeID				INTEGER				NOT NULL
			,AttributeCode				MDM.UDTShortName
			,AttributeValue				MDM.UDTLongName
			,IsDefaultValue				TINYINT				NOT NULL
			,IsActive					TINYINT				NOT NULL
			,Action						CHAR(1)
		)

		DECLARE @resultset TABLE
		(
			AttributeID INTEGER
		)

		--Update last modified date
		SET @lastModifiedDate = GETDATE()

		--READ DATA FROM JSON AND INSERT IT INTO TEMP TABLE
		IF (@jsonStringForContactAddressAttributes IS NOT NULL)
		BEGIN

			INSERT INTO @ContactAddressAttributeMaster(	
														AttributeID		
														,AttributeName			
														,IsActive				
														,IsDeleted				
														,ControlType			
														,IsMandatory			
														,IsAddressType			
														,Action		
														)
												SELECT	AttributeID		
														,AttributeName			
														,IsActive				
														,IsDeleted				
														,ControlType			
														,IsMandatory			
														,IsAddressType			
														,Action			
										FROM	OPENJSON(@jsonStringForContactAddressAttributes, '$.AttributeMaster')   
										WITH  (	
												AttributeID				INTEGER			
												,AttributeName				MDM.UDTLongName	
												,IsActive					TINYINT			
												,IsDeleted					TINYINT			
												,ControlType				INTEGER			
												,IsMandatory				TINYINT			
												,IsAddressType				TINYINT			
												,Action						CHAR(1)
											 )

			INSERT INTO @ContactAttributeMasterValues(
														AttributeMasterValueID
														,AttributeID		
														,AttributeCode	
														,AttributeValue	
														,IsDefaultValue	
														,IsActive		
														,Action		
													 )
												SELECT	AttributeMasterValueID
														,AttributeID		
														,AttributeCode	
														,AttributeValue	
														,IsDefaultValue	
														,IsActive		
														,Action		
												FROM OPENJSON(@jsonStringForContactAddressAttributes, '$.AttributeMasterMapping')
												WITH(
														AttributeMasterValueID		INTEGER
														,AttributeID				INTEGER			
														,AttributeCode				MDM.UDTShortName
														,AttributeValue				MDM.UDTLongName
														,IsDefaultValue				TINYINT			
														,IsActive					TINYINT			
														,Action						CHAR(1)
													)
		END

		--Set AttributeID for new Attribute
		SELECT	@AttributeID = NEXT VALUE FOR MDM.ContactAddressAttributeID
		UPDATE A
			SET A.AttributeID = @AttributeID
		FROM @ContactAddressAttributeMaster A
		WHERE Action = 'I'
		AND	A.AttributeID = 0

		UPDATE A
			SET A.AttributeID = @AttributeID
		FROM @ContactAttributeMasterValues A
		WHERE Action = 'I'
		AND	A.AttributeID = 0

		BEGIN TRANSACTION
			
			--Update Data into MDM.ContactAttributeMaster table when action is 'U'
			UPDATE A
				SET		A.AttributeName				=		B.AttributeName			
						,A.IsActive					=		B.IsActive				
						,A.IsDeleted				=		B.IsDeleted				
						,A.ControlType				=		B.ControlType			
						,A.IsMandatory				=		B.IsMandatory			
						,A.IsAddressType			=		B.IsAddressType			
						,A.ReviewedBy				=		@loginUser			
						,A.LastModifiedDate			=		@lastModifiedDate		
						,A.LastModifiedByUser		=		@loginUser		
						,A.LastModifiedByMachine	=		@machineName
			FROM MDM.ContactAttributeMaster A
			INNER JOIN @ContactAddressAttributeMaster B
				ON A.AttributeID = B.AttributeID
			WHERE B.Action = 'U'

			--Update Data into MDM.ContactAttributeMasterValues table when action is 'U'
			UPDATE A
				SET		A.AttributeCode				=		B.AttributeCode	
						,A.AttributeValue			=		B.AttributeValue	
						,A.IsDefaultValue			=		B.IsDefaultValue	
						,A.IsActive					=		B.IsActive		
			FROM MDM.ContactAttributeMasterValues A
			INNER JOIN @ContactAttributeMasterValues B
				ON A.AttributeMasterValueID = B.AttributeMasterValueID
			WHERE B.Action = 'U'

			--Insert Data into MDM.ContactAttributeMaster Table when Action is 'I'
			INSERT INTO MDM.ContactAttributeMaster(
													AttributeID			
													,AttributeName			
													,IsActive				
													,IsDeleted				
													,ControlType			
													,IsMandatory			
													,IsAddressType			
													,ReviewedBy				
													,LastModifiedDate		
													,LastModifiedByUser		
													,LastModifiedByMachine
												  )
											SELECT	AttributeID			
													,AttributeName			
													,IsActive				
													,IsDeleted				
													,ControlType			
													,IsMandatory			
													,IsAddressType			
													,@loginUser
													,@lastModifiedDate		
													,@loginUser		
													,@machineName
											FROM @ContactAddressAttributeMaster CAAM
											WHERE CAAM.Action = 'I'

			--Insert Data into MDM.ContactAttributeMasterValues Table when Action is 'I'
			INSERT INTO MDM.ContactAttributeMasterValues(
															AttributeID	
															,AttributeCode	
															,AttributeValue	
															,IsDefaultValue	
															,IsActive		
														)
												SELECT		AttributeID	
															,AttributeCode	
															,AttributeValue	
															,IsDefaultValue	
															,IsActive
												FROM @ContactAttributeMasterValues 
												WHERE Action = 'I'

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


