DECLARE
    v_existing_rows		NUMBER := 0;
    v_affected_rows		NUMBER := 0;
    v_operation_type	VARCHAR2(20);

    v_query_name VARCHAR2(50) := 'Reconciliation-GetBillDetails';
    v_application_name VARCHAR2(50) := 'Modernia';
    v_version_number NUMBER := 5;
    v_currentuser VARCHAR(50) := 'ServiceLayer_IA';

    v_query_value CLOB := 
      'WITH CoverageRules AS (
    SELECT 
        AsMapValue.TextValue AS CoverageVersionCode,
        MapInsuranceBasis.TextValue AS InsuranceBasis,
        InsuranceTypeCode.TextValue AS InsuranceType
    FROM AsMapGroup 
    JOIN AsMapValue ON AsMapValue.MapGroupGUID = AsMapGroup.MapGroupGUID
    JOIN AsMapCriteria InsuranceTypeCode ON InsuranceTypeCode.MapValueGUID = AsMapValue.MapValueGUID
        AND InsuranceTypeCode.MapCriteriaName = ''InsuranceTypeCode''
    JOIN AsMapCriteria MapInsuranceBasis ON MapInsuranceBasis.MapValueGUID = AsMapValue.MapValueGUID
        AND MapInsuranceBasis.MapCriteriaName = ''InsuranceBasis''
    WHERE AsMapGroup.MapGroupDescription = ''RISP_CoverageRules''
)
, PoliciesInformation AS (
    SELECT 
        AsProduct.ProductName,
        AsPlan.PlanName,
        AsPolicy.PolicyGUID,
        AsPolicy.PolicyNumber,
        SystemDesc.TranslationValue AS SystemCode,
        AsPolicy.StatusCode AS PolicyStatus,
        AsSegment.SegmentGUID,
        CoverageVersionCode.TextValue AS CoverageVersionCode,
        CoverageIdentifier.TextValue AS CoverageIdentifier,
        CoverageRules.InsuranceType
    FROM AsPolicy
    JOIN (
        SELECT 
            AsPolicy.PolicyNumber, 
            MIN(AsPolicy.SystemCode) AS SystemCode
        FROM AsPolicy
        WHERE (''[Policynumber]'' IS NULL OR INSTR(''[Policynumber]'', AsPolicy.PolicyNumber) > 0 )
        GROUP BY AsPolicy.PolicyNumber
    ) t ON t.PolicyNumber = AsPolicy.PolicyNumber
        AND t.SystemCode = AsPolicy.SystemCode
    JOIN AsPlan ON AsPlan.PlanGUID = AsPolicy.PlanGUID
    JOIN AsProduct ON AsProduct.ProductGUID = AsPlan.ProductGUID
    JOIN AsCode SystemCode ON SystemCode.CodeValue = AsPolicy.SystemCode
        AND SystemCode.CodeName = ''AsCodeSystem''
    JOIN AsTranslation SystemDesc ON SystemDesc.TranslationKey = SystemCode.ShortDescription
        AND SystemDesc.Locale = ''fr-CA''
    JOIN AsSegment ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID
    JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID
        AND CoverageIdentifier.FieldName = ''CoverageIdentifier''
    JOIN AsSegmentField CoverageVersionCode ON CoverageVersionCode.SegmentGUID = AsSegment.SegmentGUID
        AND CoverageVersionCode.FieldName = ''CoverageVersionCode''
    JOIN AsSegmentField InsuranceBasis ON InsuranceBasis.SegmentGUID = AsSegment.SegmentGUID
        AND InsuranceBasis.FieldName = ''InsuranceBasis''
    JOIN CoverageRules ON CoverageRules.CoverageVersionCode = CoverageVersionCode.TextValue
        AND CoverageRules.InsuranceBasis = InsuranceBasis.TextValue
)
,GeneratingTransactions AS (
    SELECT DISTINCT AsTransaction.TransactionGUID, AsTransaction.TransactionName 
    FROM AsTransaction
    JOIN AsBusinessRules ON AsBusinessRules.TransactionGUID = AsTransaction.TransactionGUID
        AND AsBusinessRules.RuleName = ''GenerateBillDetail''
)
, MaintainingTransactions AS (
    SELECT DISTINCT AsTransaction.TransactionGUID, AsTransaction.TransactionName 
    FROM AsTransaction
    JOIN AsBusinessRules ON AsBusinessRules.TransactionGUID = AsTransaction.TransactionGUID
        AND AsBusinessRules.RuleName = ''MaintainBillDetail''
)
, GeneratingActivities AS (
    SELECT PoliciesInformation.PolicyGUID, AsActivity.ActivityGUID, GeneratingTransactions.TransactionName, AsActivity.XMLData, AsActivity.ActivityGMT, AsActivity.TypeCode, AsActivity.EffectiveDate
    FROM AsActivity
    JOIN GeneratingTransactions ON GeneratingTransactions.TransactionGUID = AsActivity.TransactionGUID
    JOIN PoliciesInformation ON PoliciesInformation.PolicyGUID = AsActivity.PolicyGUID
    WHERE AsActivity.StatusCode = ''01''
		AND AsActivity.ActivityGMT >= TO_TIMESTAMP(''[StartDate]'', ''YYYY-MM-DD HH24:MI:SS.FF3'')
		AND AsActivity.ActivityGMT <= TO_TIMESTAMP(''[EndDate]'', ''YYYY-MM-DD HH24:MI:SS.FF3'') 
)
, MaintainingActivities AS (
    SELECT PoliciesInformation.PolicyGUID, AsActivity.ActivityGUID, MaintainingTransactions.TransactionName, AsActivity.XMLData, AsActivity.ActivityGMT, AsActivity.TypeCode, AsActivity.EffectiveDate
    FROM AsActivity
    JOIN MaintainingTransactions ON MaintainingTransactions.TransactionGUID = AsActivity.TransactionGUID
    JOIN PoliciesInformation ON PoliciesInformation.PolicyGUID = AsActivity.PolicyGUID
    WHERE AsActivity.StatusCode = ''01''
		AND AsActivity.ActivityGMT >= TO_TIMESTAMP(''[StartDate]'', ''YYYY-MM-DD HH24:MI:SS.FF3'')
		AND AsActivity.ActivityGMT <= TO_TIMESTAMP(''[EndDate]'', ''YYYY-MM-DD HH24:MI:SS.FF3'') 
)
, GeneratingActivitiesBillDetailFwd AS (
    SELECT 
        GeneratingActivities.PolicyGUID
        , GeneratingActivities.ActivityGUID
        , GeneratingActivities.EffectiveDate 
        , GeneratingActivities.ActivityGMT
        , GeneratingActivities.TransactionName
        , SUBSTR(NewBillDetail.NewBillDetailGUID,17,36) AS BillDetailGUID
        , ''PENDING'' AS StatusCode
    FROM GeneratingActivities
    JOIN XMLTABLE(''/Activity/Inserts/AsBillDetail''
        PASSING XMLPARSE(CONTENT GeneratingActivities.XMLData)
        COLUMNS NewBillDetailGUID VARCHAR(100) PATH ''./@KEY''
        ) NewBillDetail
        ON 1=1
    WHERE GeneratingActivities.TypeCode IN (''01'',''04'')    
)
, GeneratingActivitiesBillDetailBkw AS (
    SELECT 
        GeneratingActivities.PolicyGUID
        , GeneratingActivities.ActivityGUID
        , GeneratingActivities.EffectiveDate 
        , GeneratingActivities.ActivityGMT
        , GeneratingActivities.TransactionName
        , SUBSTR(REPLACE(NewBillDetail.NewBillDetailGUID, '' '', ''''),17,36) AS BillDetailGUID
        , NewBillDetail.NewBillDetailStatus AS StatusCode
    FROM GeneratingActivities
    JOIN XMLTABLE(''/Activity/Changes/AsBillDetail[@FIELD = "Status"]''
        PASSING XMLPARSE(CONTENT GeneratingActivities.XMLData)
        COLUMNS NewBillDetailGUID VARCHAR(100) PATH ''./@WHERE''
            , NewBillDetailStatus VARCHAR(100) PATH ''./New''
        ) NewBillDetail
        ON 1=1
    WHERE GeneratingActivities.TypeCode IN (''02'',''03'')    
)
, MaintainingActivitiesBillDetail AS (
    SELECT 
        MaintainingActivities.PolicyGUID
        , MaintainingActivities.ActivityGUID
        , MaintainingActivities.EffectiveDate 
        , MaintainingActivities.ActivityGMT
        , MaintainingActivities.TransactionName
        , SUBSTR(REPLACE(UpdatedBillDetail.UpdatedBillDetailGUID,'' '',''''),17,36) AS BillDetailGUID
        , UpdatedBillDetail.UpdatedBillDetailStatus AS StatusCode
    FROM MaintainingActivities
    JOIN XMLTABLE(''/Activity/Changes/AsBillDetail[@FIELD="Status"]''
        PASSING XMLPARSE(CONTENT MaintainingActivities.XMLData)
        COLUMNS 
            UpdatedBillDetailGUID VARCHAR(100) PATH ''./@WHERE''
          , UpdatedBillDetailStatus VARCHAR(100) PATH ''./New''
        ) UpdatedBillDetail
        ON 1=1
)
, ActivitiesBillDetail AS (
    SELECT tt.PolicyGUID, tt.ActivityGUID, tt.EffectiveDate, tt.ActivityGMT, tt.TransactionName, tt.BillDetailGUID, tt.StatusCode
    FROM (
        SELECT t.PolicyGUID, t.ActivityGUID, t.EffectiveDate, t.ActivityGMT, t.TransactionName, t.BillDetailGUID, t.StatusCode
            , ROW_NUMBER() OVER (PARTITION BY t.BillDetailGUID ORDER BY t.ActivityGMT DESC) AS RowNumber
        FROM (
            SELECT * 
            FROM GeneratingActivitiesBillDetailFwd 
            UNION
            SELECT * 
            FROM GeneratingActivitiesBillDetailBkw 
            UNION
            SELECT *
            FROM MaintainingActivitiesBillDetail
        ) t    
    ) tt
    WHERE tt.RowNumber = 1
)
, BillDetailsInformation AS (
    SELECT 
        ActivitiesBillDetail.BillDetailGUID,
        AsBillDetail.BillEntityType, 
        AsBillDetail.BillEntityGUID,
        AsBillDetail.BillGroupType, 
        AsBillDetail.ReceivableDueType, 
        AsBillDetail.Amount, 
        AsBillDetail.CurrencyCode, 
        AsBillDetail.DueDate,
        ActivitiesBillDetail.StatusCode,
        BillDetailCreationDate.DateValue AS BillDetailCreationDate
    FROM ActivitiesBillDetail
    JOIN AsBillDetail ON AsBillDetail.BillDetailGUID = ActivitiesBillDetail.BillDetailGUID
    JOIN AsBillDetailField BillDetailCreationDate ON BillDetailCreationDate.BillDetailGUID = AsBillDetail.BillDetailGUID 
        AND BillDetailCreationDate.FieldName = ''BillDetailCreationDate'' 
)
SELECT 
    BillDetailsInformation.BillDetailGUID,
    ActivitiesBillDetail.ActivityGUID, 
    PoliciesInformation.PolicyNumber, 
    PoliciesInformation.PolicyStatus, 
    PoliciesInformation.ProductName, 
    PoliciesInformation.PlanName, 
    PoliciesInformation.CoverageVersionCode,
    PoliciesInformation.InsuranceType,
    PoliciesInformation.CoverageIdentifier,
    ActivitiesBillDetail.TransactionName, 
    BillDetailsInformation.BillEntityType, 
    BillDetailsInformation.BillGroupType, 
    BillDetailsInformation.ReceivableDueType, 
    BillDetailsInformation.Amount, 
    BillDetailsInformation.CurrencyCode, 
    BillDetailsInformation.StatusCode, 
    TO_CHAR(BillDetailsInformation.BillDetailCreationDate, ''YYYY-MM-DD'') AS BillDetailCreationDate, 
    TO_CHAR(ActivitiesBillDetail.EffectiveDate, ''YYYY-MM-DD'') AS BillDetailChangeDate, 
    TO_CHAR(BillDetailsInformation.DueDate, ''YYYY-MM-DD'') AS DueDate,
    TO_CHAR(ActivitiesBillDetail.ActivityGMT, ''YYYY-MM-DD HH24:MI:SS.FF3'') AS ActivityGMT
FROM ActivitiesBillDetail
JOIN BillDetailsInformation ON BillDetailsInformation.BillDetailGUID = ActivitiesBillDetail.BillDetailGUID
JOIN PoliciesInformation ON PoliciesInformation.SegmentGUID = BillDetailsInformation.BillEntityGUID
ORDER BY PoliciesInformation.PolicyNumber DESC, BillDetailsInformation.DueDate DESC';

BEGIN
    -- Check if a row with the same QueryName, ApplicationName and VersionNumber already exists
    SELECT COUNT(*)
    INTO   v_existing_rows
    FROM   ASRESTSERVICEQUERY
    WHERE  QUERYNAME       = v_query_name
      AND  APPLICATIONNAME = v_application_name
      AND  VERSIONNUMBER   = v_version_number;

    -- Perform INSERT or UPDATE based on existence
    IF v_existing_rows > 0 THEN
        -- Update existing row
        UPDATE ASRESTSERVICEQUERY
        SET    QUERYVALUE = v_query_value
        WHERE  QUERYNAME       = v_query_name
          AND  APPLICATIONNAME = v_application_name
          AND  VERSIONNUMBER   = v_version_number;

        v_operation_type := 'updated';
    ELSE
        -- Insert new row
        INSERT INTO AsRestServiceQuery (RestServiceQueryGUID, QueryName, VersionNumber, QueryValue, ApplicationName, SystemIndicator, CreatedGMT, CreatedUser)
        VALUES (NEWID(), v_query_name, v_version_number, v_query_value, v_application_name, 'N', current_date, v_currentuser );

        v_operation_type := 'inserted';
    END IF;
    
    v_affected_rows := SQL%ROWCOUNT;

    -- Output the operation type and affected rows
    DBMS_OUTPUT.PUT_LINE(v_affected_rows || ' row(s) ' || v_operation_type || '.' );
END;
/