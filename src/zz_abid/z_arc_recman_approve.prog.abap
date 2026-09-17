*&---------------------------------------------------------------------*
*& Modulpool Z_ARC_FIREFIGHTER_APPROVE
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
PROGRAM z_arc_recman_approve.
TABLES: zrecman_logs.
TYPE-POOLS cndp.
*TYPE-POOLS: icon.

* Declarations
*DATA:
*  go_picture                 TYPE REF TO cl_gui_picture,
*  go_picture_container  TYPE REF TO cl_gui_custom_container.

TYPES: BEGIN OF ty_data,
         agr_name           TYPE zrecman_logs-agr_name,
         child_agr          TYPE zrecman_logs-child_agr,
         agr_name_descr     TYPE zz_agr_title,
         child_agr_descr    TYPE zz_child_title,
         wf_approval_status TYPE zrecman_logs-wf_approval_status,
         approver           TYPE zrecman_logs-approver,
         reject_reason      TYPE zrecman_logs-reject_reason,
         approved_at        TYPE zrecman_logs-approved_at,
         rejected_at        TYPE zrecman_logs-rejected_at,
         created_at         TYPE char32,
         changed_at         TYPE zrecman_logs-changed_at,
         color              TYPE lvc_t_scol,   " << Color table for cells
       END OF ty_data,
       ty_it_data TYPE STANDARD TABLE OF ty_data WITH DEFAULT KEY,
       BEGIN OF ty_s_logs,
         agr_name           TYPE zrecman_logs-agr_name,
         child_agr          TYPE zrecman_logs-child_agr,
         system_id          TYPE zrecman_logs-system_id,
         wf_approval_status TYPE zrecman_logs-wf_approval_status,
         approver           TYPE zrecman_logs-approver,
         reject_reason      TYPE zrecman_logs-reject_reason,
         approved_at        TYPE zrecman_logs-approved_at,
         rejected_at        TYPE zrecman_logs-rejected_at,
         created_at         TYPE zrecman_logs-created_at,
         changed_at         TYPE zrecman_logs-changed_at,
         color              TYPE lvc_t_scol,   " << Color table for cells
       END OF ty_s_logs,
       ty_it_logs TYPE STANDARD TABLE OF ty_s_logs WITH DEFAULT KEY,
       BEGIN OF ty_s_roles,
         agr_name           TYPE zrecman_logs-agr_name,
         child_agr          TYPE zrecman_logs-child_agr,
*         system_id          TYPE zrecman_logs-system_id,
         wf_approval_status TYPE zrecman_logs-wf_approval_status,
         approver           TYPE zrecman_logs-approver,
         reject_reason      TYPE zrecman_logs-reject_reason,
         approved_at        TYPE zrecman_logs-approved_at,
         rejected_at        TYPE zrecman_logs-rejected_at,
         created_at         TYPE zrecman_logs-created_at,
         changed_at         TYPE zrecman_logs-changed_at,
         color              TYPE lvc_t_scol,   " << Color table for cells
       END OF ty_s_roles,
       ty_it_roles TYPE STANDARD TABLE OF ty_s_roles WITH DEFAULT KEY,
       BEGIN OF ty_s_logs_tr,
         agr_name           TYPE zrecman_logs_tr-agr_name,
         child_agr          TYPE zrecman_logs_tr-child_agr,
         system_id          TYPE zrecman_logs_tr-system_id,
         blocked_role       TYPE zrecman_logs_tr-blocked_role,
         blocked_timestamp  TYPE zrecman_logs_tr-blocked_timestamp,
         blocked_by         TYPE zrecman_logs_tr-blocked_by,
         transport_no       TYPE zrecman_logs_tr-transport_no,
         wf_approval_status TYPE zrecman_logs_tr-wf_approval_status,
         approver           TYPE zrecman_logs_tr-approver,
         reject_reason      TYPE zrecman_logs_tr-reject_reason,
         approved_at        TYPE zrecman_logs_tr-approved_at,
         rejected_at        TYPE zrecman_logs_tr-rejected_at,
         created_at         TYPE zrecman_logs_tr-created_at,
         changed_at         TYPE zrecman_logs_tr-changed_at,
         color              TYPE lvc_t_scol,   " << Color table for cells
       END OF ty_s_logs_tr,
       ty_it_logs_tr TYPE STANDARD TABLE OF ty_s_logs_tr WITH DEFAULT KEY.

DATA:
  lt_pending_db  TYPE TABLE OF zcomp_role_hdr,
  lt_pending_out TYPE TABLE OF zcomp_role_hdr,
  lo_cust_200    TYPE REF TO cl_gui_custom_container,
  lo_alv_200     TYPE REF TO cl_gui_alv_grid,
  ok_code        TYPE sy-ucomm,
  save_ok        TYPE sy-ucomm,
  is_layo        TYPE lvc_s_layo,
  chk            TYPE c.

***********Start of Code by Kanishk Arora*********

DATA: lo_cust_300 TYPE REF TO cl_gui_custom_container,
      lo_alv_300  TYPE REF TO cl_gui_alv_grid.

DATA: lt_owngrp_pending TYPE TABLE OF zcomp_owngrp_req.

***********End of Code by Kanishk Arora***********

DATA: lv_in   TYPE char32, "Timestamp
      lv_out  TYPE string,
      lv_year TYPE char4,
      lv_mon  TYPE char2,
      lv_day  TYPE char2,
      lv_hh   TYPE char2,
      lv_mm   TYPE char2,
      lv_ss   TYPE char2.
* DATA: lt_pending_db TYPE TABLE OF ty_it_data.
DATA  url(132).
* custom container
DATA container TYPE REF TO cl_gui_custom_container.
* picture Control.
DATA picture TYPE REF TO cl_gui_picture.
* Definition of Control Framework
CLASS cl_gui_cfw DEFINITION LOAD.
DATA  init.

DATA: lo_alv TYPE REF TO cl_salv_table.
DATA: lv_scrtext_s TYPE scrtext_s,
      lo_functions TYPE REF TO cl_salv_functions_list.

INCLUDE z_arc_recman_approve_output.
INCLUDE z_arc_recman_approve_input.
