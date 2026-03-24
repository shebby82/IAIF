DECLARE
	VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);
	VSQL3 VARCHAR2(32767);
	VSQL4 VARCHAR2(32767);
	VSQL5 VARCHAR2(32767);
	VSQL6 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN
-- Insert FieldName ReplacedCoverageIdentifier in SegmentMultiValueField
VSQL1:= '
	INSERT INTO AsSegmentMultiValueField (SegmentGUID, FieldName, FieldIndex, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
	SELECT SegmentGUID, ''ReplacedCoverageIdentifier'', FieldIndex, ''02'', TextValue, OptionTextFlag, OptionText
	FROM 
	(
    		SELECT AsSegment.SegmentGUID , AsPolicyMultiValueField.FieldIndex, AsPolicyMultiValueField.TextValue, AsPolicyMultiValueField.OptionTextFlag, AsPolicyMultiValueField.OptionText
    		FROM AsSegment
    		JOIN AsPolicyMultiValueField ON AsPolicyMultiValueField.PolicyGUID = AsSegment.PolicyGUID
        		AND AsPolicyMultiValueField.FieldName = ''ReplacedCoverageIdentifier''
   		 WHERE AsSegment.SegmentGUID NOT IN 
        	(	
        		SELECT SegmentGUID 
        		FROM AsSegmentMultiValueField 
        		WHERE FieldName LIKE ''%ReplacedCoverageIdentifier%''
       		)
    	)';

-- Insert FieldName ReplacedCoverageIssueYearText in SegmentMultiValueField 
VSQL2:= '
	INSERT INTO AsSegmentMultiValueField (SegmentGUID, FieldName, FieldIndex, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
	SELECT SegmentGUID, ''ReplacedCoverageIssueYearText'', FieldIndex, ''02'', TextValue, OptionTextFlag, OptionText
	FROM 
	(
    		SELECT AsSegment.SegmentGUID , AsPolicyMultiValueField.FieldIndex, AsPolicyMultiValueField.TextValue, AsPolicyMultiValueField.OptionTextFlag, AsPolicyMultiValueField.OptionText
    		FROM AsSegment
    		JOIN AsPolicyMultiValueField ON AsPolicyMultiValueField.PolicyGUID = AsSegment.PolicyGUID
        		AND AsPolicyMultiValueField.FieldName = ''ReplacedCoverageIssueYear''
   		 WHERE AsSegment.SegmentGUID NOT IN 
        	(	
        		SELECT SegmentGUID 
        		FROM AsSegmentMultiValueField 
        		WHERE FieldName LIKE ''%ReplacedCoverageIssueYear%''
       		)
    	)';

-- Insert FieldName ReplacedCoveragePolicyNumber in SegmentMultiValueField 
VSQL3:= '
	INSERT INTO AsSegmentMultiValueField (SegmentGUID, FieldName, FieldIndex, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
	SELECT SegmentGUID, ''ReplacedCoveragePolicyNumber'', FieldIndex, ''02'', TextValue, OptionTextFlag, OptionText
	FROM 
	(
    		SELECT AsSegment.SegmentGUID , AsPolicyMultiValueField.FieldIndex, AsPolicyMultiValueField.TextValue, AsPolicyMultiValueField.OptionTextFlag, AsPolicyMultiValueField.OptionText
    		FROM AsSegment
    		JOIN AsPolicyMultiValueField ON AsPolicyMultiValueField.PolicyGUID = AsSegment.PolicyGUID
        		AND AsPolicyMultiValueField.FieldName = ''ReplacedCoveragePolicyNumber''
   		 WHERE AsSegment.SegmentGUID NOT IN 
        	(	
        		SELECT SegmentGUID 
        		FROM AsSegmentMultiValueField 
        		WHERE FieldName LIKE ''%ReplacedCoveragePolicyNumber%''
       		)
    	)';

-- Insert FieldName ReplacementContext in SegmentMultiValueField 
VSQL4:= '
	INSERT INTO AsSegmentMultiValueField (SegmentGUID, FieldName, FieldIndex, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
	SELECT SegmentGUID, ''ReplacementContext'', FieldIndex, ''02'', TextValue, OptionTextFlag, OptionText
	FROM 
	(
    		SELECT AsSegment.SegmentGUID , AsPolicyMultiValueField.FieldIndex, AsPolicyMultiValueField.TextValue, AsPolicyMultiValueField.OptionTextFlag, AsPolicyMultiValueField.OptionText
    		FROM AsSegment
    		JOIN AsPolicyMultiValueField ON AsPolicyMultiValueField.PolicyGUID = AsSegment.PolicyGUID
        		AND AsPolicyMultiValueField.FieldName = ''ReplacementContext''
   		 WHERE AsSegment.SegmentGUID NOT IN 
        	(	
        		SELECT SegmentGUID 
        		FROM AsSegmentMultiValueField 
        		WHERE FieldName LIKE ''%ReplacementContext%''
       		)
    	)';

-- Insert FieldName ReplacementType in SegmentMultiValueField 
VSQL5:= '
	INSERT INTO AsSegmentMultiValueField (SegmentGUID, FieldName, FieldIndex, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
	SELECT SegmentGUID, ''ReplacementType'', FieldIndex, ''02'', TextValue, OptionTextFlag, OptionText
	FROM 
	(
    		SELECT AsSegment.SegmentGUID , AsPolicyMultiValueField.FieldIndex, AsPolicyMultiValueField.TextValue, AsPolicyMultiValueField.OptionTextFlag, AsPolicyMultiValueField.OptionText
    		FROM AsSegment
    		JOIN AsPolicyMultiValueField ON AsPolicyMultiValueField.PolicyGUID = AsSegment.PolicyGUID
        		AND AsPolicyMultiValueField.FieldName = ''ReplacementType''
   		 WHERE AsSegment.SegmentGUID NOT IN 
        	(	
        		SELECT SegmentGUID 
        		FROM AsSegmentMultiValueField 
        		WHERE FieldName LIKE ''%ReplacementType%''
       		)
    	)';

 VSQL6 := '
    INSERT INTO AsSegmentMultiValueField (SegmentGUID, FieldName, FieldIndex, FieldTypeCode, DateValue)
	SELECT AsSegment.SegmentGUID, ''ReplacedCoverageEffectiveDate'', AsSegmentMultiValueField.FieldIndex, ''01'', NULL
        FROM AsSegment
        JOIN AsSegmentMultiValueField ON AsSegmentMultiValueField.SegmentGUID = AsSegment.SegmentGUID 
            AND AsSegmentMultiValueField.FieldName = ''ReplacedCoverageIdentifier''
        WHERE AsSegment.SegmentGUID NOT IN 
        	(	
        		SELECT SegmentGUID 
        		FROM AsSegmentMultiValueField 
        		WHERE FieldName LIKE ''ReplacedCoverageEffectiveDate''
       		)';

VRESULT := NULL;

	EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );
	EXECUTESQL ( VSQL3, VRESULT );
	EXECUTESQL ( VSQL4, VRESULT );
	EXECUTESQL ( VSQL5, VRESULT );
	EXECUTESQL ( VSQL6, VRESULT );
END;
/