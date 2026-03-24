DECLARE
	VSQL1 VARCHAR2(32767);
	VRESULT VARCHAR2(200);

BEGIN
VSQL1:= '
	INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, FloatValue)
    SELECT AsRole.RoleGUID, ''ReinsuranceForcedRateAdjustmentFactor'', ''04'', 1
    FROM AsRole
    WHERE AsRole.RoleCode = ''97''
        AND AsRole.RoleGUID NOT IN (
            SELECT RoleGUID 
            FROM AsRoleField 
            WHERE FieldName = ''ReinsuranceForcedRateAdjustmentFactor''
        )
	';

VRESULT := NULL;
	EXECUTESQL ( VSQL1, VRESULT );

END;
/