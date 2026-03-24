
-- ***SCRIPT 1311_Insert_SegmentFields_GuaranteedInsurability NEEDS TO BE RUN BEFORE ***

BEGIN
   -- We need to Check in production if there were protections coming from a GI
    
    SELECT CoverageIdentifier.TextValue AS CoverageIdentifier, AsSegment.SegmentGUID As SegmenGUID, CoverageStatus.TextValue, AsPolicy.SystemCode
    FROM AsSegment 
    JOIN AsPolicy on AsPolicy.PolicyGUID = AsSegment.PolicyGUID
    JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID 
      AND CoverageIdentifier.FieldName = 'CoverageIdentifier'   
    JOIN AsSegmentField CoverageStatus ON CoverageStatus.SegmentGUID = AsSegment.SegmentGUID 
      AND CoverageStatus.FieldName = 'CoverageStatus'   
    JOIN AsSegmentField CoverageGuaranteedInsurabilityIndicator ON CoverageGuaranteedInsurabilityIndicator.SegmentGUID = AsSegment.SegmentGUID 
      AND CoverageGuaranteedInsurabilityIndicator.FieldName = 'CoverageGuaranteedInsurabilityIndicator' 
      AND CoverageGuaranteedInsurabilityIndicator.TextValue = 'CHECKED'
    

-- Once values determined, below query will need to be UPDATE, possible stored procedure to update all related fields for a given CoverageIdentifier    
  
    -- Update OriginTransaction field (OptionText needs to be the LongDescription)
    UPDATE AsSegmentField 
    SET TextValue = '', OptionText =''
    WHERE FieldName = 'OriginTransaction'
      AND SegmentGUID = '' ;

    -- Update OriginSystemSource field (OptionText needs to be the LongDescription)
    UPDATE AsSegmentField
    SET TextValue = '', OptionText =''
    WHERE FieldName = 'OriginSystemSource'
      AND SegmentGUID = '' ;

    -- Update OriginPolicyNumber field
    UPDATE AsSegmentField
    SET TextValue = ''
    WHERE FieldName = 'OriginPolicyNumber'
      AND SegmentGUID = '' ;

    -- Update OriginCoverageIdentifier field
    UPDATE AsSegmentField
    SET TextValue = ''
    WHERE FieldName = 'OriginCoverageIdentifier'
      AND SegmentGUID = '' ;

    -- Update OriginCoverageEffectiveDate field
    UPDATE AsSegmentField
    SET DateValue = TO_DATE('', 'YYYY-MM-DD')
    WHERE FieldName = 'OriginCoverageEffectiveDate'
      AND SegmentGUID = '' ;

    
-- Delete CoverageGuaranteedInsurabilityIndicator  
   
   
    DELETE FROM AsSegmentField 
    WHERE FieldName = 'CoverageGuaranteedInsurabilityIndicator'
    ;
   
    
-- We need to check in production if there have been any GI exercise requests, on Application
    
    SELECT CoverageIdentifier.TextValue AS CoverageIdentifier,OriginCoverageIdentifier.TextValue AS OriginCoverageIdentifier, AsSegment.SegmentGUID As SegmenGUID, CoverageStatus.TextValue, AsPolicy.SystemCode
    FROM AsPolicy
    JOIN AsPolicyField ON AsPolicyField.PolicyGUID = AsPolicy.PolicyGUID
    JOIN AsSegment ON AsSegment.PolicyGUID = AsPolicy.PolicyGUID
    JOIN AsSegmentField CoverageIdentifier ON CoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID
      AND CoverageIdentifier.FieldName = 'CoverageIdentifier'
    JOIN AsSegmentField CoverageStatus ON CoverageStatus.SegmentGUID = AsSegment.SegmentGUID 
      AND CoverageStatus.FieldName = 'CoverageStatus'
    JOIN AsSegmentField OriginCoverageIdentifier on OriginCoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID
        AND OriginCoverageIdentifier.FieldName ='OriginCoverageIdentifier'
    WHERE AsPolicyField.FieldName = 'ApplicationSubType'
      AND AsPolicyField.TextValue = '03'
      AND AsPolicy.StatusCode NOT IN ('04', '06', '12')
      AND AsPolicy.SystemCode = '02'

-- Once values determined, below query will need to be UPDATE, te all related fields for a given CoverageIdentifier on the Policy Only

    --Query to find the SegmentGUID of the Origin Coverage Identifier on the Policy
    Select AsSegment.SegmentGUID , CoverageStatus.TextValue
    From AsSegment
    JOIN AsSegmentField CoverageIdentifier on CoverageIdentifier.SegmentGUID = AsSegment.SegmentGUID
        AND CoverageIdentifier.FieldName ='CoverageIdentifier'
        AND CoverageIdentifier.TextValue =''
    JOIN AsSegmentField CoverageStatus on CoverageStatus.SegmentGUID = AsSegment.SegmentGUID
        AND CoverageStatus.FieldName ='CoverageStatus'
    JOIN AsPolicy On AsPolicy.PolicyGUID = AsSegment.PolicyGUID
        AND AsPolicy.SystemCode ='01'
      
    UPDATE AsSegmentField
    SET IntValue = ''
    WHERE FieldName = 'GuaranteedInsurabilityExerciseCount'
      AND SegmentGUID = '' ;
      
    
END;
/