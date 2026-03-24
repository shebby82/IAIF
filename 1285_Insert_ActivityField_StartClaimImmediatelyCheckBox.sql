DECLARE
	VSQL1 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN
-- Insert FieldName StartClaimImmediatelyCheckBox in CalculateClaimDisbursement, CalculateClaimDisbursementNonReversible and ProcessInsuredClaim
VSQL1:= '
	INSERT INTO AsActivityField (ActivityGUID, FieldName, FieldTypeCode, TextValue)
	SELECT ActivityGUID, ''StartClaimImmediatelyCheckBox'', ''02'', ''UNCHECKED''
	FROM (
        SELECT AsActivity.ActivityGUID FROM AsActivity
        JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
            AND AsTransaction.TransactionName IN (''CalculateClaimDisbursement'',''CalculateClaimDisbursementNonReversible'',''ProcessInsuredClaim'')
        WHERE AsActivity.ActivityGUID NOT IN (
            SELECT AsActivity.ActivityGUID FROM AsActivity
            JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
                AND AsTransaction.TransactionName IN (''CalculateClaimDisbursement'',''CalculateClaimDisbursementNonReversible'',''ProcessInsuredClaim'')
            JOIN AsActivityField ON AsActivityField.ActivityGUID = AsActivity.ActivityGUID 
                AND AsActivityField.FieldName = ''StartClaimImmediatelyCheckBox''
        )
	)';

    VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );

END;
/