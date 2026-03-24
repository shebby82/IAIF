DECLARE 
  VSQL1 VARCHAR2(32767);

  VRESULT VARCHAR2(32767);

BEGIN 
		  
	VSQL1 := '
	DELETE FROM AsPolicyMultiValueField
	WHERE FieldName IN (''ReplacedCoverageIdentifier'', ''ReplacedCoverageIssueYear'', ''ReplacedCoveragePolicyNumber'', ''ReplacementContext'', ''ReplacementType'')
		  ';

	VRESULT := NULL;

	EXECUTESQL ( VSQL1, VRESULT );
	
END;
/