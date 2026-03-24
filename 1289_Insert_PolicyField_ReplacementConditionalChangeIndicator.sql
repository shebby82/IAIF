DECLARE
   VSQL1 VARCHAR2(32767);
VRESULT VARCHAR2(200);
BEGIN
    VSQL1 := '
        INSERT INTO AsPolicyField (PolicyGUID, FieldName, FieldTypeCode, TextValue)
        SELECT PolicyGUID, ''ReplacementConditionalChangeIndicator'', ''02'', ''UNCHECKED''
        FROM AsPolicy
        WHERE PolicyGUID NOT IN (
            SELECT PolicyGUID 
            FROM AsPolicyField 
            WHERE FieldName = ''ReplacementConditionalChangeIndicator''
            )';

VRESULT := NULL;

    EXECUTESQL ( VSQL1, VRESULT );
     
END;
/