DECLARE

    CURSOR SegmentInfo_Cursor IS 

    WITH SegmentList As
    (
        SELECT AsPolicy.PolicyGUID,AsSegment.SegmentGUID 
            FROM AsSegmentField
        JOIN AsSegment ON AsSegment.SegmentGUID = AsSegmentField.SegmentGUID
        JOIN AsPolicy ON AsPolicy.PolicyGUID = AsSegment.PolicyGUID 
            AND SystemCode = '02'
        JOIN AsPolicyField ON AsPolicyField.PolicyGUID = AsPolicy.PolicyGUID 
            AND AsPolicyField.FieldName='ApplicationType' 
            AND AsPolicyField.TextValue='01'
        JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegmentField.SegmentGUID
            AND CoverageIdentifier.FieldName='CoverageIdentifier'
        WHERE AsSegmentField.FieldName='CoverageVersionCode' 
            AND AsSegmentField.TextValue='CIGI-202401'
    )
    SELECT SegmentList.SegmentGUID, CoverageIdentifier.TextValue 
        FROM SegmentList
    JOIN AsSegment ON AsSegment.PolicyGUID = SegmentList.PolicyGUID
    JOIN AsPolicy ON AsPolicy.PolicyGUID = SegmentList.PolicyGUID
    JOIN AsSegmentField ON AsSegmentField.SegmentGUID = AsSegment.SegmentGUID
    JOIN AsMapValue ON AsMapValue.TextValue = AsSegmentField.TextValue
    JOIN AsMapCriteria ON AsMapCriteria.MapValueGUID = AsMapValue.MapValueGUID 
    JOIN AsMapGroup ON AsMapGroup.MapGroupGUID = AsMapValue.MapGroupGUID 
    JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID 
        AND CoverageIdentifier.FieldName='CoverageIdentifier'
    JOIN AsSegmentField SegmentStatus ON SegmentStatus.SegmentGUID = AsSegmentField.SegmentGUID 
        AND SegmentStatus.FieldName = 'CoverageStatus' 
        AND SegmentStatus.TextValue != '04'
    WHERE AsSegmentField.FieldName='CoverageVersionCode' 
        AND AsSegmentField.TextValue != 'CIGI-202401'
        AND AsMapGroup.MapGroupDescription = 'RISP_CoverageValidationRules' 
        AND AsMapCriteria.TextValue='CritIlln';

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