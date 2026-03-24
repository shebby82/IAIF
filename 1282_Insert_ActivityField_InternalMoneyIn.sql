DECLARE 
	VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);
	VRESULT VARCHAR2(200);
  

BEGIN
-- Insert Fieldname ClaimNumber in Transactions InternalMoneyIn 
	VSQL1:= '
	INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode)
	SELECT ActivityGUID, ''ClaimNumber'', ''02''
	FROM (
		SELECT AsActivity.ActivityGUID FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''InternalMoneyIn'')
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT AsActivity.ActivityGUID FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
				AND AsTransaction.TransactionName IN (''InternalMoneyIn'')
			JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
				AND AsActivityField.FieldName = ''ClaimNumber''
		)
	)';

-- Insert Fieldname CoverageIdentifier in Transactions InternalMoneyIn 
	VSQL2:= '
	INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode)
	SELECT ActivityGUID, ''CoverageIdentifier'', ''02''
	FROM (
		SELECT AsActivity.ActivityGUID FROM AsActivity
		JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
			AND AsTransaction.TransactionName IN (''InternalMoneyIn'')
		WHERE AsActivity.ActivityGUID NOT IN (
			SELECT AsActivity.ActivityGUID FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
				AND AsTransaction.TransactionName IN (''InternalMoneyIn'')
			JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
				AND AsActivityField.FieldName = ''CoverageIdentifier''
		)
	)';

	VRESULT := NULL;

	EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );
END;
/