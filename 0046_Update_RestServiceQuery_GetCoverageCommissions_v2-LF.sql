
DECLARE
    v_existing_rows   NUMBER := 0;
    v_affected_rows   NUMBER := 0;
    v_operation_type  VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'GetCoverageCommissions';
    v_application_name VARCHAR2(50) := 'Modernia';
    v_version_number NUMBER := 2;

    v_query_value CLOB := '
    SELECT
		AsActivity.ActivityGUID,
		TO_CHAR (AsActivity.EffectiveDate, ''YYYY-MM-DD'') ACTIVITYEFFECTIVEDATE,
		EqPushEvent.EventName,
		EqPushEvent.MessageRequest,
        CASE
            WHEN AsTransaction.TransactionName = ''TerminateCoverage'' THEN
                (AsSegmentFieldCurrentFaceAmount.FloatValue * -1)
            WHEN AsTransaction.TransactionName = ''ReduceCoverageFaceAmount'' THEN
                AsActivityFieldNewFaceAmount.FloatValue  - AsActivityFieldCurrentFaceAmount.FloatValue
            WHEN AsTransaction.TransactionName = ''TerminatePolicy'' THEN
                (AsSegmentFieldCurrentFaceAmount.FloatValue * -1)
            WHEN AsTransaction.TransactionName = ''ActivateCoverage'' THEN
                AsSegmentFieldCurrentFaceAmount.FloatValue
            ELSE
                Null
        END AS ActivityAmount
	FROM AsCommissionDetail
	JOIN AsActivity ON AsActivity.ActivityGUID = AsCommissionDetail.OriginatingActivityGUID
	JOIN AsPolicy ON AsPolicy.PolicyGUID = AsActivity.PolicyGUID
	JOIN EqPushEvent ON AsActivity.ActivityGUID = EqPushEvent.ActivityGUID
	JOIN AsCommissionDetailField PolicyNumber ON PolicyNumber.CommissionDetailGUID = AsCommissionDetail.CommissionDetailGUID
		AND PolicyNumber.FieldName = ''PolicyNumber''
	JOIN AsCommissionDetailField CoverageIdentifier ON CoverageIdentifier.CommissionDetailGUID = PolicyNumber.CommissionDetailGUID
		AND CoverageIdentifier.FieldName = ''CoverageIdentifier''
	JOIN AsCommissionDetailField CommissionReason ON CommissionReason.CommissionDetailGUID = PolicyNumber.CommissionDetailGUID
		AND CommissionReason.FieldName = ''CommissionReason''
    JOIN AsSegmentField AsSegmentFieldCoverageIdentifier ON CoverageIdentifier.TextValue = AsSegmentFieldCoverageIdentifier.TextValue
        AND AsSegmentFieldCoverageIdentifier.FieldName = ''CoverageIdentifier''
    JOIN AsSegmentField AsSegmentFieldCoverageStatus ON AsSegmentFieldCoverageIdentifier.SegmentGUID = AsSegmentFieldCoverageStatus.SegmentGUID
        AND AsSegmentFieldCoverageStatus.FieldName = ''CoverageStatus''
        AND AsSegmentFieldCoverageStatus.TextValue NOT IN (''12'')
    JOIN AsSegmentField AsSegmentFieldCurrentFaceAmount ON AsSegmentFieldCoverageIdentifier.SegmentGUID = AsSegmentFieldCurrentFaceAmount.SegmentGUID
        AND AsSegmentFieldCurrentFaceAmount.FieldName = ''CurrentFaceAmount''
    JOIN AsSegment On AsSegment.SegmentGUID = AsSegmentFieldCoverageIdentifier.SegmentGUID
        AND AsPolicy.PolicyGUID = AsSegment.PolicyGUID
    JOIN AsActivitySpawn ON AsActivitySpawn.ActivityGUID = AsActivity.ActivityGUID
    JOIN AsActivity SpawnedBy ON AsActivitySpawn.SpawnedByGUID = SpawnedBy.ActivityGUID
	JOIN AsTransaction ON AsTransaction.TransactionGUID = SpawnedBy.TransactionGUID
    LEFT JOIN AsActivityField AsActivityFieldCurrentFaceAmount ON AsActivityFieldCurrentFaceAmount.ActivityGUID = SpawnedBy.ActivityGUID
        AND AsActivityFieldCurrentFaceAmount.FieldName = ''CurrentFaceAmount''
    LEFT JOIN AsActivityField AsActivityFieldNewFaceAmount ON AsActivityFieldNewFaceAmount.ActivityGUID = SpawnedBy.ActivityGUID
        AND AsActivityFieldNewFaceAmount.FieldName = ''NewFaceAmount''
	WHERE AsCommissionDetail.StatusCode = ''GENRTD''
		AND (PolicyNumber.TextValue = TRIM (''[PolicyNumber]'') AND TRIM (''[PolicyNumber]'') IS NOT NULL)
		AND AsPolicy.SystemCode = ''01''
		AND (CoverageIdentifier.TextValue = TRIM (''[CoverageIdentifier]'') AND TRIM (''[CoverageIdentifier]'') IS NOT NULL)
		AND
		(
			(''[CoverageOption]'' = ''01'' AND CommissionReason.TextValue IN (''03'')) OR
			(''[CoverageOption]'' = ''02'' AND CommissionReason.TextValue IN (''03'', ''05'', ''06'', ''07'')) OR
			(''[CoverageOption]'' = ''03'' AND CommissionReason.TextValue IN (''16'')) OR
			(''[CoverageOption]'' = ''04'' AND CommissionReason.TextValue IN (''03'', ''13'', ''14'', ''15''))
		)
	';

BEGIN
    SELECT COUNT(*)
    INTO   v_existing_rows
    FROM   ASRESTSERVICEQUERY
    WHERE  QUERYNAME       = v_query_name
      AND  APPLICATIONNAME = v_application_name
     ;

    IF v_existing_rows > 0 THEN
        UPDATE ASRESTSERVICEQUERY
        SET    QUERYVALUE = v_query_value,
               VERSIONNUMBER   = v_version_number
        WHERE  QUERYNAME       = v_query_name
          AND  APPLICATIONNAME = v_application_name;

        v_operation_type := 'updated';
    ELSE
        INSERT INTO AsRestServiceQuery (RestServiceQueryGUID, QueryName, VersionNumber, QueryValue, ApplicationName)
        VALUES (NEWID(), v_query_name, v_version_number, v_query_value, v_application_name);

        v_operation_type := 'inserted';
    END IF;

    v_affected_rows := SQL%ROWCOUNT;

    DBMS_OUTPUT.PUT_LINE(v_affected_rows || ' row(s) ' || v_operation_type || '.' );
END;
/