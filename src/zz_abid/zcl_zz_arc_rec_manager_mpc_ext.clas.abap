class ZCL_ZZ_ARC_REC_MANAGER_MPC_EXT definition
  public
  inheriting from ZCL_ZZ_ARC_REC_MANAGER_MPC
  create public .

public section.

***  types:
***    BEGIN OF ty_deep_entity,
***        agr_name           TYPE c LENGTH 30,
***        agr_name_descr     TYPE c LENGTH 80,
***        wf_approval_status TYPE c LENGTH 20,
***        approver           TYPE c LENGTH 50,
***        reject_reason      TYPE c LENGTH 80,
***        approved_at        TYPE c LENGTH 32,
***        rejected_at        TYPE c LENGTH 32,
***        created_at         TYPE c LENGTH 32,
***        changed_at         TYPE c LENGTH 32,
***        create_flag        TYPE flag,
**** Navigation property name should be used otherwise empty records will be shown
***        to_items           TYPE TABLE OF ts_zcomproleitem WITH DEFAULT KEY,
***      END OF ty_deep_entity .

***  methods DEFINE
***    redefinition .
protected section.
private section.
ENDCLASS.



CLASS ZCL_ZZ_ARC_REC_MANAGER_MPC_EXT IMPLEMENTATION.
ENDCLASS.
