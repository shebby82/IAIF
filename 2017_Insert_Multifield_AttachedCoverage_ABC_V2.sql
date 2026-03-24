DECLARE

    CURSOR SegmentInfo_Cursor IS 

    WITH SegmentList As
    (
        SELECT AsPolicy.PolicyNumber, AsSegmentField.SegmentGUID,AsSegmentField.TextValue 
            FROM AsSegmentField
            JOIN AsSegment ON AsSegment.SegmentGUID = AsSegmentField.SegmentGUID
            JOIN AsPolicy ON AsPolicy.PolicyGUID = AsSegment.PolicyGUID 
                AND SystemCode = '02'
            JOIN AsSegmentField ApplicationIdentifier ON ApplicationIdentifier.SegmentGUID = AsSegmentField.SegmentGUID 
                AND ApplicationIdentifier.FieldName='ApplicationIdentifier'
            JOIN AsPolicy PolicyIssued ON PolicyIssued.PolicyNumber = AsPolicy.PolicyNumber 
                AND PolicyIssued.SystemCode = '01'
            JOIN AsSegment PolicySegment ON PolicySegment.PolicyGUID = PolicyIssued.PolicyGUID
            JOIN AsSegmentField PolicySegmentField ON PolicySegmentField.SegmentGUID = PolicySegment.SegmentGUID 
                AND PolicySegmentField.FieldName = 'ApplicationIdentifier'
            JOIN AsSegmentField SegmentStatus ON SegmentStatus.SegmentGUID = PolicySegmentField.SegmentGUID 
                AND SegmentStatus.FieldName = 'CoverageStatus' 
                AND SegmentStatus.TextValue = '01'
            JOIN AsSegmentField CoverageVersionCode ON CoverageVersionCode.SegmentGUID = PolicySegmentField.SegmentGUID 
                AND CoverageVersionCode.FieldName='CoverageVersionCode'
            JOIN AsSegmentField AddedCoverageVersionCode ON AddedCoverageVersionCode.SegmentGUID = AsSegmentField.SegmentGUID
                AND AddedCoverageVersionCode.FieldName='CoverageVersionCode'
            JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = PolicySegmentField.SegmentGUID 
                AND CoverageIdentifier.FieldName='CoverageIdentifier'
            JOIN AsMapValue ON AsMapValue.TextValue = AddedCoverageVersionCode.TextValue
            JOIN AsMapCriteria ON AsMapCriteria.MapValueGUID = AsMapValue.MapValueGUID 
            JOIN AsMapGroup ON AsMapGroup.MapGroupGUID = AsMapValue.MapGroupGUID 
            WHERE AsMapGroup.MapGroupDescription = 'RISP_CoverageValidationRules' 
                AND AsMapCriteria.TextValue='CritIlln' 
                AND AsSegmentField.FieldName='CoverageIdentifier'
                AND CoverageVersionCode.TextValue='CIGI-202401' 
                AND PolicySegmentField.TextValue != ApplicationIdentifier.TextValue 
        UNION 
            SELECT  AsPolicy.PolicyNumber, AsSegment.SegmentGUID, CoverageIdentifier.TextValue 
            FROM AsSegmentField
            JOIN AsSegment ON AsSegment.SegmentGUID = AsSegmentField.SegmentGUID
            JOIN AsSegment CoverageVersionCodeSegment ON AsSegment.SegmentGUID = CoverageVersionCodeSegment.SegmentGUID
            JOIN AsPolicy ON AsPolicy.PolicyGUID = AsSegment.PolicyGUID 
                AND SystemCode = '02'
            JOIN AsPolicyField ON AsPolicyField.PolicyGUID = AsPolicy.PolicyGUID 
                AND AsPolicyField.FieldName='ApplicationType' 
                AND AsPolicyField.TextValue = '02'
            JOIN AsSegmentField SegmentStatus ON SegmentStatus.SegmentGUID = AsSegmentField.SegmentGUID 
                AND SegmentStatus.FieldName = 'CoverageStatus' 
                AND SegmentStatus.TextValue != '04'
            JOIN AsSegmentField CoverageVersionCode ON CoverageVersionCode.SegmentGUID = AsSegmentField.SegmentGUID 
                AND CoverageVersionCode.FieldName='CoverageVersionCode'
            JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegmentField.SegmentGUID 
                AND CoverageIdentifier.FieldName='CoverageIdentifier'
            JOIN AsMapValue ON AsMapValue.TextValue = CoverageVersionCode.TextValue
            JOIN AsMapCriteria ON AsMapCriteria.MapValueGUID = AsMapValue.MapValueGUID 
            JOIN AsMapGroup ON AsMapGroup.MapGroupGUID = AsMapValue.MapGroupGUID 
                AND AsMapGroup.MapGroupDescription = 'RISP_CoverageValidationRules'
                AND AsMapCriteria.TextValue='CritIlln'
            WHERE AsSegmentField.FieldName='CoverageVersionCode'   
    ) 
    
    SELECT AsSegment.SegmentGUID,SegmentList.TextValue 
    FROM SegmentList
    JOIN AsPolicy ON AsPolicy.PolicyNumber = SegmentList.PolicyNumber 
        AND AsPolicy.SystemCode='02'
    JOIN AsPolicyField ON AsPolicyField.PolicyGUID = AsPolicy.PolicyGUID 
        AND AsPolicyField.FieldName='ApplicationType' 
        AND AsPolicyField.TextValue='02'
    JOIN AsSegment ON AsSegment.PolicyGUID = AsPolicyField.PolicyGUID
    JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsSegment.SegmentGUID
    WHERE AsSegmentField.FieldName='CoverageVersionCode' 
        AND AsSegmentField.TextValue = 'CIGI-202401' 
        AND SegmentList.SegmentGUID != AsSegment.SegmentGUID;
    
    -- Variables to hold cursor data
    v_segmentGUID AsSegment.SegmentGUID%TYPE;
    v_coverageIdentifier VARCHAR2(765 BYTE);
   
BEGIN

    -- Open the cursor and process each record
    OPEN SegmentInfo_Cursor;

    LOOP 
        -- Fetch data into the variables
        FETCH SegmentInfo_Cursor INTO v_segmentGUID, v_coverageIdentifier;

        -- Exit when no more rows to fetch
        EXIT WHEN SegmentInfo_Cursor%NOTFOUND;
        
        -- Declare a scalar variable to hold the count
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT count(1) INTO v_count FROM AsSegmentMultivalueField
            WHERE SegmentGUID = v_segmentGUID;

            -- Use the scalar variable in the INSERT statement
            INSERT INTO AsSegmentMultivalueField (SegmentGuid, FieldName, FieldIndex, FieldTypeCode, TextValue)
                VALUES(v_segmentGUID, 'AttachedCoverage', v_count, '02', v_coverageIdentifier);
        END;

    END LOOP;

    -- Close the cursor
    CLOSE SegmentInfo_Cursor;

END;
/