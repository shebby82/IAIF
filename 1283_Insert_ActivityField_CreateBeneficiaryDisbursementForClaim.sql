DECLARE 
	VSQL1 VARCHAR2(32767);
	VRESULT VARCHAR2(200);
  

BEGIN
-- Insert Fieldname CoverageIdentifier in Transactions CreateBeneficiaryDisbursementForClaim 
	VSQL1:= '
	INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode)
	SELECT ActivityGUID, ''CoverageIdentifier'', ''02''
	FROM (
		SELECT AsActivity.ActivityGUID
		FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName = ''CreateBeneficiaryDisbursementForClaim''
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT AsActivity.ActivityGUID
			FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
				AND AsTransaction.TransactionName = ''CreateBeneficiaryDisbursementForClaim''
			JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
				AND AsActivityField.FieldName = ''CoverageIdentifier''
			)
	)';


	VRESULT := NULL;

	EXECUTESQL ( VSQL1, VRESULT );
END;
/