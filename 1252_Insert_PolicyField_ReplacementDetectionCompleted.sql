DECLARE
   VSQL1 VARCHAR2(32767);
VRESULT VARCHAR2(200);
BEGIN
    VSQL1 := '
        INSERT INTO AsPolicyField (PolicyGUID, FieldName, FieldTypeCode, TextValue)
        SELECT PolicyGUID, ''ReplacementDetectionCompleted'', ''02'', ''UNCHECKED''
        FROM AsPolicy
        WHERE PolicyGUID NOT IN (
            SELECT PolicyGUID 
            FROM AsPolicyField 
            WHERE FieldName = ''ReplacementDetectionCompleted''
            )';

VRESULT := NULL;

    EXECUTESQL ( VSQL1, VRESULT );
     
END;
/