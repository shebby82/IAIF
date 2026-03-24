DECLARE 
    VSQL1 VARCHAR2(32767);
    VRESULT VARCHAR2(200);
    
BEGIN 
VSQL1:= '
          DELETE FROM AsActivityMultiValueField
          WHERE AsActivityMultiValueField.ActivityGUID IN (
            SELECT AsActivity.ActivityGUID FROM AsActivity
            JOIN AsTransaction ON AsTransaction.TransactionGUID = AsActivity.TransactionGUID
                AND AsTransaction.TransactionName = ''ProcessApplicationUnderwritingDecision''
          )
		';

VRESULT := NULL;

    EXECUTESQL ( VSQL1, VRESULT );    
    
END;
/