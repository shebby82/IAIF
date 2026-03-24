DECLARE
	VSQL1 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN

VSQL1:= '
	INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode)
	SELECT ActivityGUID, ''ServiceRequestID'', ''02''
	FROM AsActivity
	WHERE ActivityGUID IN 
	(
		SELECT DISTINCT(AsActivity.ActivityGUID)
		FROM AsActivity
		JOIN AsTransaction ON AsActivity.TransactionGUID = AsTransaction.TransactionGUID
			AND AsTransaction.TransactionName IN (''AddCoverageRolesAtIssueAsFile'',''CancelCoverageAtIssue'',''CompleteCoverageAdditionAtIssue'')
	)
	AND ActivityGUID NOT IN 
	(
		SELECT DISTINCT(AsActivity.ActivityGUID)
		FROM AsActivity
		JOIN AsActivityField ON AsActivity.ActivityGUID = AsActivityField.ActivityGUID
			AND AsActivityField.FieldName = ''ServiceRequestID''
		JOIN AsTransaction ON AsActivity.TransactionGUID = AsTransaction.TransactionGUID
			AND AsTransaction.TransactionName IN (''AddCoverageRolesAtIssueAsFile'',''CancelCoverageAtIssue'',''CompleteCoverageAdditionAtIssue'')
	)
	';

VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );

END;
/