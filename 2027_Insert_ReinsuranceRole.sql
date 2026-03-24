BEGIN   
        INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue)
            WITH RoleSequence AS (
                SELECT AsRole.SegmentGUID, AsRole.RoleGUID, AsRole.RoleCode, AsSegmentField.TextValue, 
                    ROW_NUMBER() OVER (PARTITION BY AsRole.SegmentGUID ORDER BY AsRole.RoleGUID) AS RoleSequence
                FROM AsRole
                JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsRole.SegmentGUID
                    AND AsSegmentField.FieldName = 'CoverageIdentifier'
                JOIN AsSegment ON AsSegment.SegmentGUID = AsSegmentField.SegmentGUID
                    AND AsSegment.StatusCode != '12'
                WHERE AsRole.RoleCode = '97'
                    AND AsRole.StatusCode = '01'
                )
        SELECT RoleGUID, 'RiskCessionIdentifier', '02', TextValue || '-RC' || RoleSequence
        FROM RoleSequence 
        WHERE RoleGUID NOT IN 
            (SELECT RoleGUID FROM AsRoleField WHERE FieldName = 'RiskCessionIdentifier');	
END;
/