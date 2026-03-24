DECLARE 
    VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);
	VSQL3 VARCHAR2(32767);

    VRESULT VARCHAR2(200);

BEGIN
	-- Insert ActivityField AsFileIndicator in ChangeCoverageAtIssue
	VSQL1:= '
		INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode,TextValue)
		SELECT ActivityGUID, ''AsFileIndicator'', ''02'',''UNCHECKED''
		FROM (
			SELECT AsActivity.ActivityGUID FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
				AND AsTransaction.TransactionName IN (''ChangeCoverageAtIssue'')
			WHERE AsActivity.ActivityGUID NOT IN (
				SELECT AsActivity.ActivityGUID FROM AsActivity
				JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
					AND AsTransaction.TransactionName IN (''ChangeCoverageAtIssue'')
				JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
					AND AsActivityField.FieldName = ''AsFileIndicator''
			)
		)';

	-- Insert ActivityField NewFaceAmount in ChangeCoverageAtIssue
	VSQL2:='
		INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, FloatValue, CurrencyCode)
		SELECT ActivityGUID, ''NewFaceAmount'', ''04'', 0, ''CAD''
		FROM AsActivity
		WHERE ActivityGUID IN (
			SELECT DISTINCT(AsActivity.ActivityGUID) FROM AsActivity
			JOIN AsTransaction ON AsActivity.TransactionGUID = AsTransaction.TransactionGUID AND AsTransaction.TransactionName = ''ChangeCoverageAtIssue''
			)
			AND ActivityGUID NOT IN (
				SELECT DISTINCT(AsActivity.ActivityGUID) FROM AsActivity
				JOIN AsActivityField ON AsActivity.ActivityGUID = AsActivityField.ActivityGUID AND AsActivityField.FieldName = ''NewFaceAmount''
				JOIN AsTransaction ON AsActivity.TransactionGUID = AsTransaction.TransactionGUID AND AsTransaction.TransactionName = ''ChangeCoverageAtIssue''
				)
			';

	-- Insert ActivityField ServiceRequestID in ChangeFaceAmountAtIssue, AddCoverageAtIssue, AddCoverageAtIssueAsFile, ChangeCoverageAtIssue
	VSQL3:= '
		INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode)
		SELECT ActivityGUID, ''ServiceRequestID'', ''02''
		FROM (
			SELECT AsActivity.ActivityGUID FROM AsActivity
			JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
				AND AsTransaction.TransactionName IN (''ChangeFaceAmountAtIssue'',''AddCoverageAtIssue'',''ChangeCoverageAtIssue'')
			WHERE AsActivity.ActivityGUID NOT IN (
				SELECT AsActivity.ActivityGUID FROM AsActivity
				JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
					AND AsTransaction.TransactionName IN (''ChangeFaceAmountAtIssue'',''AddCoverageAtIssue'',''ChangeCoverageAtIssue'')
				JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
					AND AsActivityField.FieldName = ''ServiceRequestID''
			)
		)';	
		
	
	
VRESULT := NULL;
    EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );
	EXECUTESQL ( VSQL3, VRESULT );
END;
/