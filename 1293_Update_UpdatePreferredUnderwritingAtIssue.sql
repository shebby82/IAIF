DECLARE 
    VSQL1 VARCHAR2(32767);
    VRESULT VARCHAR2(200); 
    
    BEGIN
    
    VSQL1:='
      UPDATE AsTransaction Set TransactionName =  ''UpdateUnderwritingInformationAtIssue'' WHERE TransactionName = ''UpdatePreferredUnderwritingAtIssue''
		';
	   		
	VRESULT := NULL;
    EXECUTESQL ( VSQL1, VRESULT );

END;
/