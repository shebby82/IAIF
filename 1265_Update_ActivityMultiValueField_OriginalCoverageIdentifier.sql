DECLARE 
    VSQL1 VARCHAR2(32767);
    VRESULT VARCHAR2(200);
    
BEGIN 
	-- Rename CoverageIdentifier to OriginalCoverageIdentifier in AsActivityMultiValueField
	VSQL1:='
		UPDATE AsActivityMultiValueField SET FieldName = ''OriginalCoverageIdentifier''
		WHERE FieldName = ''CoverageIdentifier'' 
			AND ActivityGUID IN (
				SELECT ActivityGUID
				FROM AsActivity
				JOIN AsTransaction ON AsActivity.TransactionGUID = AsTransaction.TransactionGUID
					AND AsTransaction.TransactionName IN (''ReduceCoverageFaceAmount'', ''TerminateCoverage'', ''TerminatePolicy'')
				)
		';
    
    
VRESULT := NULL;

EXECUTESQL ( VSQL1, VRESULT );

END;
/