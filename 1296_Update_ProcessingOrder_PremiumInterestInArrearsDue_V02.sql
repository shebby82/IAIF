DECLARE 
    VSQL1 VARCHAR2(32767);
    VRESULT VARCHAR2(200);

BEGIN 
VSQL1:=
	'
		UPDATE AsActivity SET ProcessingOrder = ''45550'' 
		WHERE TransactionGUID IN 
		(
			SELECT TransactionGUID
			FROM AsTransaction
			WHERE TransactionName IN (''PremiumInterestInArrearsDue'')
		)
	';
	
	VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );

END;
/