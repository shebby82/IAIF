DECLARE
	VSQL1 VARCHAR2(32767);
	VSQL2 VARCHAR2(32767);
	VSQL3 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN
-- Insert FieldName OriginTransaction in SegmentField 
	VSQL1:='
        INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
        SELECT SegmentGUID, ''OriginTransaction'', ''02'', ''01'', 1, ''AsCodeOriginTransaction.DefaultLD''
        FROM (
            SELECT AsSegment.SegmentGUID
            FROM AsSegment
            WHERE AsSegment.SegmentGUID NOT IN (
                SELECT SegmentGUID
                FROM AsSegmentField
                WHERE FieldName = ''OriginTransaction''
                )
            )';

-- Insert FieldName OriginSystemSource in SegmentField 
	VSQL2:='
        INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, TextValue, OptionTextFlag, OptionText)
        SELECT SegmentGUID, ''OriginSystemSource'', ''02'', ''00'', 1, ''AsCodeComboBlankLD''
        FROM (
            SELECT AsSegment.SegmentGUID
            FROM AsSegment
            WHERE AsSegment.SegmentGUID NOT IN (
                SELECT SegmentGUID
                FROM AsSegmentField
                WHERE FieldName = ''OriginSystemSource''
                )
            )';
-- Insert ReinsuranceAnomalyIndicator in AsSegmentField
	VSQL3:='
		INSERT INTO AsSegmentField (SegmentGUID, FieldName, FieldTypeCode, TextValue)
		SELECT SegmentGUID, ''ReinsuranceAnomalyIndicator'', ''02'', ''UNCHECKED''
		FROM AsSegment
		WHERE AsSegment.SegmentGUID NOT IN 
			(
			SELECT AsSegmentField.SegmentGUID
			FROM AsSegment
			JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsSegment.SegmentGUID
			WHERE AsSegmentField.FieldName = ''ReinsuranceAnomalyIndicator''
			)';
	
    VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );
	EXECUTESQL ( VSQL2, VRESULT );
	EXECUTESQL ( VSQL3, VRESULT );

END;
/