DECLARE 
    VSQL1 VARCHAR2(32767);
    VRESULT VARCHAR2(200);
    
BEGIN 
VSQL1:= '
        	INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, FloatValue)
	        SELECT SegmentGUID, ''PremiumRateAdjustmentFactor'', ''04'', 1
	        FROM AsSegment 
	        WHERE AsSegment.SegmentGUID NOT IN 
			(	
				SELECT SegmentGUID 
				FROM AsSegmentField 
				WHERE FieldName = ''PremiumRateAdjustmentFactor''
			)
		';

VRESULT := NULL;

    EXECUTESQL ( VSQL1, VRESULT );    
    
END;
/