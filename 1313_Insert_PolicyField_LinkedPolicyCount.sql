DECLARE
   VSQL1 VARCHAR2(32767);
VRESULT VARCHAR2(200);
BEGIN
    VSQL1 := '
        INSERT INTO AsPolicyField (PolicyGUID, FieldName, FieldTypeCode, IntValue)
        SELECT PolicyGUID, ''LinkedPolicyCount'', ''03'', 1
        FROM AsPolicy
        WHERE PolicyGUID NOT IN (
            SELECT PolicyGUID 
            FROM AsPolicyField 
            WHERE FieldName = ''LinkedPolicyCount''
            )';

VRESULT := NULL;

    EXECUTESQL ( VSQL1, VRESULT );
     
END;
/