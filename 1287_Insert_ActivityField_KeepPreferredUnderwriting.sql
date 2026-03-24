DECLARE
	VSQL1 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN
VSQL1:= '
	INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
	SELECT ActivityGUID, ''KeepPreferredUnderwriting'', ''02'', ''UNCHECKED''
	FROM AsActivity
	JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
		AND AsTransaction.TransactionName = ''ChangeTobaccoUseAtIssue''
	WHERE ActivityGUID NOT IN 
	(
		SELECT DISTINCT(AsActivity.ActivityGUID)
		FROM AsActivityField
		WHERE AsActivityField.FieldName = ''KeepPreferredUnderwriting''
	)
	';

VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );

END;
/