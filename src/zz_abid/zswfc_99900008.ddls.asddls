@AbapCatalog.sqlViewName: 'ZSWF99900008'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #PRIVILEGED_ONLY
@EndUserText.label: 'Generated: Flex Workflow CDS for scenario WS99900008'
@ObjectModel: {
  usageType.serviceQuality: #X,
  usageType.sizeCategory: #S,
  usageType.dataClass: #MASTER
}
@ClientHandling.algorithm: #SESSION_VARIABLE
define view ZSWFC_99900008
with parameters wf_id:sww_wiid
as select from ZSWFM_99900008(wf_id:$parameters.wf_id) as MetaData


{
  key MetaData.WorkflowId
  , MetaData._WF_INITIATOR AS S___WF_INITIATOR
  , MetaData._WF_PRIORITY AS S___WF_PRIORITY
  , MetaData._WF_VERSION AS S___WF_VERSION
}
where MetaData.WorkflowId = $parameters.wf_id;
