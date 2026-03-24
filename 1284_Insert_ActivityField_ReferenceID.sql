DECLARE
	VSQL1 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN
-- Insert FieldName ReferenceID in MoneyOut 
VSQL1:= '
	INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode)
		SELECT ActivityGUID, ''ReferenceID'', ''02''
		FROM (
			SELECT AsActivity.ActivityGUID FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
				AND AsTransaction.TransactionName IN (''MoneyOut'')
			WHERE AsActivity.ActivityGUID NOT IN (
				SELECT AsActivity.ActivityGUID FROM AsActivity
				JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
					AND AsTransaction.TransactionName IN (''MoneyOut'')
				JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
					AND AsActivityField.FieldName = ''ReferenceID''
			)
		)';
	
    VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );

END;
/