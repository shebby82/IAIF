DECLARE
	VSQL1 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN
-- Insert FieldName CurrentFaceAmount in SegmentField 
VSQL1:= '
	INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, FloatValue, CurrencyCode)
	SELECT AsSegmentField.SegmentGUID, ''CurrentFaceAmount'', ''04'', AsSegmentField.FloatValue, AsSegmentField.CurrencyCode
	FROM AsSegmentField 
	WHERE AsSegmentField.FieldName = ''FaceAmount'' 
		AND AsSegmentField.SegmentGUID NOT IN 
			(	
				SELECT SegmentGUID 
				FROM AsSegmentField 
				WHERE FieldName = ''CurrentFaceAmount''
			)
	';
	
    VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );

END;
/