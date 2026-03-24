DECLARE

    CURSOR SegmentInfo_Cursor IS 
    WITH SegmentList As (
        SELECT ApplicationCoverageIdentifier.SegmentGUID, AsSegment.SegmentGUID AS PoilcySegmentGUID, ApplicationCoverageIdentifier.TextValue 
        FROM AsPolicy
        JOIN AsSegment ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID 
            AND SystemCode = '01'
        JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID 
            AND CoverageIdentifier.FieldName='CoverageIdentifier'
        JOIN AsSegmentField CoverageVersionCode ON CoverageVersionCode.SegmentGUID =  AsSegment.SegmentGUID 
            AND CoverageVersionCode.FieldName='CoverageVersionCode' 
            AND CoverageVersionCode.TextValue = 'CIGI-202401' 
        JOIN AsPolicy policyApplication ON policyApplication.PolicyNumber = AsPolicy.PolicyNumber 
            AND policyApplication.SystemCode = '02'
        JOIN AsSegment ApplicationSegment ON ApplicationSegment.PolicyGUID = policyApplication.PolicyGUID
        JOIN AsSegmentField ApplicationCoverageIdentifier ON ApplicationCoverageIdentifier.SegmentGUID = ApplicationSegment.SegmentGUID 
            AND ApplicationCoverageIdentifier.FieldName='CoverageIdentifier'
        JOIN AsSegmentField SegmentStatus ON SegmentStatus.SegmentGUID = ApplicationCoverageIdentifier.SegmentGUID 
            AND SegmentStatus.FieldName = 'CoverageStatus' 
            AND SegmentStatus.TextValue != '04'
        JOIN AsSegmentMultivalueField ON AsSegmentMultivalueField.SegmentGUID  = ApplicationCoverageIdentifier.SegmentGUID
        WHERE ApplicationCoverageIdentifier.TextValue = CoverageIdentifier.TextValue
    )
    SELECT Distinct(SegmentList.PoilcySegmentGUID), AsSegmentMultivalueField.TextValue FROM SegmentList
    JOIN AsSegmentMultivalueField ON AsSegmentMultivalueField.SegmentGUID = SegmentList.SegmentGUID 
        AND FieldName='AttachedCoverage';

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