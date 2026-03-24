BEGIN
    -- ReinsurerExtraPremiumInsureds
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue)
    SELECT RoleGUID, 'ReinsurerExtraPremiumInsureds', '02', PartyID
    FROM (
        WITH PartyIDList AS (
            SELECT JLTDRole.SegmentGUID, 
                   UPPER(LISTAGG(PartyID.TextValue, '|') 
                   WITHIN GROUP (ORDER BY PartyID.TextValue) || '|') AS PartyIDs
            FROM AsClientField PartyID
            JOIN AsClient ON PartyID.ClientGUID = AsClient.ClientGUID
            JOIN AsRole JLTDRole ON JLTDRole.ClientGUID = AsClient.ClientGUID
                AND JLTDRole.RoleCode = '37'
                AND JLTDRole.StatusCode IN ('01','02')
            WHERE PartyID.FieldName = 'PartyID'
            GROUP BY JLTDRole.SegmentGUID
        )
        SELECT DISTINCT AsRole.RoleGUID, AsClientField.TextValue || '|' AS PartyID
        FROM AsRole 
        JOIN AsRoleField ON AsRole.RoleGUID = AsRoleField.RoleGUID
        JOIN PartyIDList ON PartyIDList.SegmentGUID = AsRole.SegmentGUID
        JOIN AsRole PartyIDRole ON PartyIDRole.RoleGUID = AsRoleField.TextValue 
            AND AsRoleField.TextValue != 'JLTD' 
            AND AsRoleField.FieldName = 'Insured'
        JOIN AsClient ON AsClient.ClientGUID = PartyIDRole.ClientGUID
        JOIN AsClientField ON AsClientField.ClientGUID = AsClient.ClientGUID 
            AND AsClientField.FieldName='PartyID'
        WHERE AsRole.RoleCode = '97'
            AND AsRoleField.RoleGUID NOT IN (
                SELECT RoleGUID FROM AsRoleField WHERE FieldName = 'ReinsurerExtraPremiumInsureds'
                )
        UNION
        SELECT DISTINCT AsRole.RoleGUID, PartyIDList.PartyIDs AS PartyID
        FROM AsRole 
        JOIN PartyIDList ON PartyIDList.SegmentGUID = AsRole.SegmentGUID
        JOIN AsRoleField JLTD ON AsRole.RoleGUID = JLTD.RoleGUID 
            AND JLTD.TextValue = 'JLTD' 
            AND JLTD.FieldName = 'Insured'
        WHERE AsRole.RoleCode = '97'
            AND JLTD.RoleGUID NOT IN (
                SELECT RoleGUID FROM AsRoleField WHERE FieldName = 'ReinsurerExtraPremiumInsureds'
                )
    );

    -- ReinsurerExtraPremiumRatingPRP
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue)
    SELECT RoleGUID, 'ReinsurerExtraPremiumRatingPRP', '02', CoverageExtraPremiumRatingPRP
        FROM (
            WITH PremiumValuesList AS (
            SELECT AsRole.SegmentGUID,
                UPPER(LISTAGG(
                        CASE 
                            WHEN CoverageExtraPremiumRatingPRP.FloatValue = 0 OR CoverageExtraPremiumRatingPRP.FloatValue IS NULL THEN '0'
                            ELSE TRIM(TO_CHAR(CoverageExtraPremiumRatingPRP.FloatValue, '0.99'))
                            END, '|' ) 
                            WITHIN GROUP (ORDER BY CoverageExtraPremiumRatingPRP.FloatValue)) || '|' AS CoverageExtraPremiumRatingPRP
            FROM AsRoleField CoverageExtraPremiumRatingPRP
            JOIN AsRole ON AsRole.RoleGUID = CoverageExtraPremiumRatingPRP.RoleGUID
                AND AsRole.RoleCode = '37'
                AND AsRole.StatusCode IN ('01','02')
            WHERE CoverageExtraPremiumRatingPRP.FieldName = 'CoverageExtraPremiumRatingPRP'
            GROUP BY AsRole.SegmentGUID
         )
        SELECT DISTINCT AsRole.RoleGUID, PremiumValuesList.CoverageExtraPremiumRatingPRP
        FROM AsRole 
        JOIN AsRoleField ON AsRole.RoleGUID = AsRoleField.RoleGUID
        JOIN PremiumValuesList ON PremiumValuesList.SegmentGUID = AsRole.SegmentGUID
        WHERE AsRole.RoleCode = '97'
            AND AsRole.StatusCode = '01'
            AND AsRoleField.RoleGUID NOT IN (
                SELECT RoleGUID FROM AsRoleField WHERE FieldName = 'ReinsurerExtraPremiumRatingPRP'
                )
    );
    
    -- ReinsurerExtraPremiumAmountPRD
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue)
    SELECT RoleGUID, 'ReinsurerExtraPremiumAmountPRD', '02', CoverageExtraPremiumAmountPRD
    FROM (
        WITH PremiumValuesList AS (
            SELECT AsRole.SegmentGUID, UPPER(LISTAGG(NVL(CoverageExtraPremiumAmountPRD.FloatValue, '0'), '|') 
            WITHIN GROUP (ORDER BY CoverageExtraPremiumAmountPRD.FloatValue) || '|') AS CoverageExtraPremiumAmountPRD
                FROM AsRoleField CoverageExtraPremiumAmountPRD
                JOIN AsRole ON AsRole.RoleGUID = CoverageExtraPremiumAmountPRD.RoleGUID
                    AND AsRole.RoleCode = '37'
                    AND AsRole.StatusCode IN ('01','02')
                WHERE CoverageExtraPremiumAmountPRD.FieldName = 'CoverageExtraPremiumAmountPRD'
                GROUP BY AsRole.SegmentGUID
        )
        SELECT DISTINCT AsRole.RoleGUID, PremiumValuesList.CoverageExtraPremiumAmountPRD
        FROM AsRole 
        JOIN AsRoleField ON AsRole.RoleGUID = AsRoleField.RoleGUID
        JOIN PremiumValuesList 
            ON PremiumValuesList.SegmentGUID = AsRole.SegmentGUID
        WHERE AsRole.RoleCode = '97' 
            AND AsRole.StatusCode = '01'
            AND AsRoleField.RoleGUID NOT IN (
                SELECT RoleGUID FROM AsRoleField WHERE FieldName = 'ReinsurerExtraPremiumAmountPRD'
                )
    );

    -- ReinsurerExtraPremiumAmountTRD
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue)
    SELECT RoleGUID, 'ReinsurerExtraPremiumAmountTRD', '02', CoverageExtraPremiumAmountTRD
    FROM (
    WITH PremiumValuesList AS (
        SELECT AsRole.SegmentGUID, UPPER(LISTAGG(NVL(CoverageExtraPremiumAmountTRD.FloatValue, '0'), '|') 
        WITHIN GROUP (ORDER BY CoverageExtraPremiumAmountTRD.FloatValue) || '|') AS CoverageExtraPremiumAmountTRD
        FROM AsRoleField CoverageExtraPremiumAmountTRD
        JOIN AsRole ON AsRole.RoleGUID = CoverageExtraPremiumAmountTRD.RoleGUID
            AND AsRole.RoleCode = '37'
            AND AsRole.StatusCode IN ('01','02')
        WHERE CoverageExtraPremiumAmountTRD.FieldName = 'CoverageExtraPremiumAmountTRD'
        GROUP BY AsRole.SegmentGUID
    )
    SELECT DISTINCT AsRole.RoleGUID, PremiumValuesList.CoverageExtraPremiumAmountTRD
    FROM AsRole 
    JOIN AsRoleField ON AsRole.RoleGUID = AsRoleField.RoleGUID
    JOIN PremiumValuesList ON PremiumValuesList.SegmentGUID = AsRole.SegmentGUID
    WHERE AsRole.RoleCode = '97' 
        AND AsRole.StatusCode = '01'
        AND AsRoleField.RoleGUID NOT IN (
            SELECT RoleGUID FROM AsRoleField WHERE FieldName = 'ReinsurerExtraPremiumAmountTRD'
            )
    );

    -- ReinsurerExtraPremiumDurationTRD
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue)
    SELECT RoleGUID, 'ReinsurerExtraPremiumDurationTRD', '02', CoverageExtraPremiumDurationTRD
    FROM (
    WITH PremiumValuesList AS (
        SELECT AsRole.SegmentGUID, UPPER(LISTAGG(NVL(CoverageExtraPremiumDurationTRD.IntValue, '0'), '|') 
        WITHIN GROUP (ORDER BY CoverageExtraPremiumDurationTRD.IntValue) || '|') AS CoverageExtraPremiumDurationTRD
        FROM AsRoleField CoverageExtraPremiumDurationTRD
        JOIN AsRole ON AsRole.RoleGUID = CoverageExtraPremiumDurationTRD.RoleGUID
            AND AsRole.RoleCode = '37'
            AND AsRole.StatusCode IN ('01','02')
        WHERE CoverageExtraPremiumDurationTRD.FieldName = 'CoverageExtraPremiumDurationTRD'
        GROUP BY AsRole.SegmentGUID
    )
    SELECT DISTINCT AsRole.RoleGUID, PremiumValuesList.CoverageExtraPremiumDurationTRD
    FROM AsRole 
    JOIN AsRoleField ON AsRole.RoleGUID = AsRoleField.RoleGUID
    JOIN PremiumValuesList ON PremiumValuesList.SegmentGUID = AsRole.SegmentGUID
    WHERE AsRole.RoleCode = '97' 
        AND AsRole.StatusCode = '01'
        AND AsRoleField.RoleGUID NOT IN (
            SELECT RoleGUID FROM AsRoleField WHERE FieldName = 'ReinsurerExtraPremiumDurationTRD'
            )
    );

    -- ReinsurerExtraPremiumExpiryDateTRD
    INSERT INTO AsRoleField (RoleGUID, FieldName, FieldTypeCode, TextValue)
    SELECT RoleGUID, 'ReinsurerExtraPremiumExpiryDateTRD', '02', CoverageExtraPremiumExpiryDateTRD
    FROM (
    WITH PremiumValuesList AS (
        SELECT AsRole.SegmentGUID, REPLACE(UPPER(LISTAGG(NVL(TO_CHAR(CoverageExtraPremiumExpiryDateTRD.DateValue,'YYYY-MM-DD'), 'x'), '|') 
        WITHIN GROUP (ORDER BY CoverageExtraPremiumExpiryDateTRD.DateValue) || '|'), 'X', '') AS CoverageExtraPremiumExpiryDateTRD
        FROM AsRoleField CoverageExtraPremiumExpiryDateTRD
        JOIN AsRole ON AsRole.RoleGUID = CoverageExtraPremiumExpiryDateTRD.RoleGUID
            AND AsRole.RoleCode = '37'
            AND AsRole.StatusCode IN ('01','02')
        WHERE CoverageExtraPremiumExpiryDateTRD.FieldName = 'CoverageExtraPremiumExpiryDateTRD'
        GROUP BY AsRole.SegmentGUID
    )
    SELECT DISTINCT AsRole.RoleGUID, PremiumValuesList.CoverageExtraPremiumExpiryDateTRD
    FROM AsRole 
    JOIN AsRoleField ON AsRole.RoleGUID = AsRoleField.RoleGUID
    JOIN PremiumValuesList ON PremiumValuesList.SegmentGUID = AsRole.SegmentGUID
    WHERE AsRole.RoleCode = '97' 
        AND AsRole.StatusCode = '01'
        AND AsRoleField.RoleGUID NOT IN (
            SELECT RoleGUID FROM AsRoleField WHERE FieldName = 'ReinsurerExtraPremiumExpiryDateTRD'
            )
    );

END;
/