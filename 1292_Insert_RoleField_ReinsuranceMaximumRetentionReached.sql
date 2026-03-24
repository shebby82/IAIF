DECLARE
	VSQL1 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN
-- Insert Insert RoleField ReinsuranceMaximumRetentionReached on Reinsurer
VSQL1:= 
        '
        INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue)
        SELECT RoleGUID, ''ReinsuranceMaximumRetentionReached'', ''02'', ''UNCHECKED'' 
        FROM AsRole 
        WHERE RoleCode = ''97''
            AND RoleGUID NOT IN (
                SELECT RoleGUID 
                FROM AsRoleField
                WHERE AsRoleField.FieldName = ''ReinsuranceMaximumRetentionReached''
			)
		'; 
	
    VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );

END;
/