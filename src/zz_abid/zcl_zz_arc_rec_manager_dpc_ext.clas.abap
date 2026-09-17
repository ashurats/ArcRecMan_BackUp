class ZCL_ZZ_ARC_REC_MANAGER_DPC_EXT definition
  public
  inheriting from ZCL_ZZ_ARC_REC_MANAGER_DPC
  create public .

public section.

  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_EXPANDED_ENTITY
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_EXPANDED_ENTITYSET
    redefinition .
protected section.

  methods COMPROLESINGLERO_GET_ENTITYSET
    redefinition .
  methods KPISET_GET_ENTITYSET
    redefinition .
  methods OWNERGROUPAPPROV_GET_ENTITYSET
    redefinition .
  methods OWNERGROUP_SH_SE_GET_ENTITYSET
    redefinition .
  methods PENDINGAPPROVALS_GET_ENTITYSET
    redefinition .
  methods ROLESLOGSSET_GET_ENTITYSET
    redefinition .
  methods TRANSPORTROLESSE_GET_ENTITYSET
    redefinition .
  methods ZCOMPROLEHDRSET_CREATE_ENTITY
    redefinition .
  methods ZCOMPROLEHDRSET_GET_ENTITY
    redefinition .
  methods ZCOMPROLEHDRSET_GET_ENTITYSET
    redefinition .
  methods ZCOMPROLEITEMSET_GET_ENTITY
    redefinition .
  methods ZCOMPROLEITEMSET_GET_ENTITYSET
    redefinition .
  methods DOWNLOADROLES_LO_GET_ENTITYSET
    redefinition .
private section.

  methods SAVE_ZCOMP_ROLE_HDR
    importing
      !IV_CREATE_FLAG type CHAR1 optional
      !IS_HDR type ZCL_ZZ_ARC_REC_MANAGER_MPC_EXT=>TS_ZCOMPROLEHDR
      !IT_ITEMS type ZCL_ZZ_ARC_REC_MANAGER_MPC_EXT=>TT_ZCOMPROLEITEM .
ENDCLASS.



CLASS ZCL_ZZ_ARC_REC_MANAGER_DPC_EXT IMPLEMENTATION.


  METHOD /iwbep/if_mgw_appl_srv_runtime~create_deep_entity.
*****
    DATA: lt_ret1 TYPE bapiret2_t,
          lt_ret2 TYPE bapiret2_t,
          lt_act  TYPE TABLE OF agr_txt,
          ls_act  LIKE LINE OF lt_act.

    DATA(lo_mc) = me->mo_context->get_message_container( ).
    DATA: BEGIN OF ls_deep.
            INCLUDE TYPE zcl_zz_arc_rec_manager_mpc=>ts_zcomprolehdr.
    DATA to_items1 TYPE zcl_zz_arc_rec_manager_mpc=>tt_zcomproleitem.
    DATA: END OF ls_deep.

    DATA: ls_hdr   TYPE zcomp_role_hdr,
          lt_item  TYPE TABLE OF zcomp_role_hdr,
          lt_item2 TYPE TABLE OF zcomp_role_hdr.


    IF iv_entity_set_name = 'ZCompRoleHdrSet'.

      CALL METHOD io_data_provider->read_entry_data(
        IMPORTING
          es_data = ls_deep ).

      ls_hdr   = CORRESPONDING #( ls_deep ).
      lt_item  = CORRESPONDING #( ls_deep-to_items1 ).

      IF lt_item IS NOT INITIAL.
        "Fetch already-processed (APPROVED/REJECTED etc. => not PENDING)
        SELECT *
          FROM zcomp_role_hdr
          INTO TABLE @DATA(lt_data)
          FOR ALL ENTRIES IN @lt_item
          WHERE agr_name            = @lt_item-agr_name
            AND child_agr           = @lt_item-child_agr
            AND wf_approval_status <> 'PENDING'.
        IF sy-subrc EQ 0.
          SORT lt_data BY agr_name child_agr.

          LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
            READ TABLE lt_item ASSIGNING FIELD-SYMBOL(<ls_item>)
              WITH KEY agr_name  = <ls_data>-agr_name
                       child_agr = <ls_data>-child_agr.
*              BINARY SEARCH.
            IF sy-subrc = 0.
              DELETE lt_item INDEX sy-tabix.
            ENDIF.
          ENDLOOP.

        ENDIF.
      ENDIF.


      "2) Validation

      "1.a) Fetch Role Description if empty
      LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<fs_item>).
        IF <fs_item>-child_agr_descr IS INITIAL.
          SELECT SINGLE text FROM agr_texts INTO @DATA(lv_agr_texts)
            WHERE agr_name = @<fs_item>-child_agr
            AND spras = @sy-langu.
          IF sy-subrc EQ 0.
            <fs_item>-child_agr_descr = lv_agr_texts.
          ENDIF.
        ENDIF.
      ENDLOOP.

      IF ls_hdr-agr_name IS NOT INITIAL.
        LOOP AT lt_item ASSIGNING <fs_item>.
          IF <fs_item>-agr_name NE ls_hdr-agr_name.
            lo_mc->add_message_text_only( iv_msg_type = 'E' iv_msg_text = 'Composite Role is invalid, please check the entries' ).
            RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
              EXPORTING
                message_container = lo_mc.
          ENDIF.
        ENDLOOP.
      ENDIF.


      IF ls_hdr-agr_name IS INITIAL.
        lo_mc->add_message_text_only( iv_msg_type = 'E' iv_msg_text = 'AGR_NAME is required.' ).
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_mc.
      ENDIF.

      IF ls_hdr-agr_name_descr IS INITIAL.
        lo_mc->add_message_text_only( iv_msg_type = 'E' iv_msg_text = 'AGR_NAME_DESCR is required.' ).
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_mc.
      ENDIF.

      READ TABLE lt_item ASSIGNING <fs_item> WITH KEY agr_name = ls_hdr-agr_name.
      IF sy-subrc EQ 0.
        SELECT SINGLE * FROM agr_define INTO @DATA(ls_agr_define)
          WHERE agr_name = @<fs_item>-child_agr.
        IF sy-subrc EQ 0.
          " Do Nothing
        ELSE.
          lo_mc->add_message_text_only( iv_msg_type = 'E' iv_msg_text = 'Single Role is not valid' ).
          RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
            EXPORTING
              message_container = lo_mc.
        ENDIF.
      ENDIF.

      IF lt_item IS NOT INITIAL.
        "3) Create Composite role & add single roles
        CALL FUNCTION 'PRGN_RFC_CREATE_AGR_MULTIPLE'
          EXPORTING
            activity_group      = ls_hdr-agr_name
            activity_group_text = ls_hdr-agr_name_descr
            collective_agr      = abap_true
          TABLES
            return              = lt_ret1
          EXCEPTIONS
            OTHERS              = 8.

        IF line_exists( lt_ret1[ type = 'E' ] )
        OR line_exists( lt_ret1[ type = 'A' ] )
        OR line_exists( lt_ret1[ type = 'X' ] ).
          ROLLBACK WORK.
          zcl_odata_msg=>raise_bapiret2( io_mc = lo_mc it_ret = lt_ret1 ).
*          RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
*            EXPORTING
*              message_container = lo_mc.
          ls_hdr-create_flag = abap_false.  " Set Create Flag " "
        ELSE.
          ls_hdr-create_flag = abap_true.  " Set Create Flag "X"
        ENDIF.

        LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<i>) WHERE wf_approval_status = 'PENDING'.
          CLEAR ls_act.
          ls_act-agr_name = <i>-child_agr.
          ls_act-text     = <i>-child_agr_descr.
          APPEND ls_act TO lt_act.
        ENDLOOP.

        CALL FUNCTION 'PRGN_RFC_ADD_AGRS_TO_COLL_AGR'
          EXPORTING
            activity_group  = ls_hdr-agr_name
          TABLES
            activity_groups = lt_act
            return          = lt_ret2
          EXCEPTIONS
            OTHERS          = 7.

        IF line_exists( lt_ret2[ type = 'E' ] )
        OR line_exists( lt_ret2[ type = 'A' ] )
        OR line_exists( lt_ret2[ type = 'X' ] ).
          ROLLBACK WORK.
          zcl_odata_msg=>raise_bapiret2( io_mc = lo_mc it_ret = lt_ret2 ).
          RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
            EXPORTING
              message_container = lo_mc.
        ENDIF.
      ENDIF.


      IF lt_item IS NOT INITIAL.
        "4) Save Z table rows (one per item)
        me->save_zcomp_role_hdr(
          iv_create_flag = ls_hdr-create_flag
          is_hdr         = ls_hdr
          it_items       = lt_item ).

        TYPES: BEGIN OF ty_cd,
                 upd TYPE cdchngind,        " 'I' / 'U' / 'D'  (per-row operation)
                 n   TYPE zcomp_role_hdr,   " new data
                 o   TYPE zcomp_role_hdr,   " old data
               END OF ty_cd.

        DATA: lt_cd      TYPE STANDARD TABLE OF ty_cd,
              ls_cd      TYPE ty_cd,
              ls_old     TYPE zcomp_role_hdr,
              lv_obj_ind TYPE cdhdr-change_ind.

        lv_obj_ind = COND #( WHEN ls_hdr-create_flag = 'X' THEN 'I' ELSE 'U' ).


        SELECT *
          FROM zcomp_role_hdr
          INTO TABLE @DATA(it_snapshot)
*          FOR ALL ENTRIES IN @lt_item
          WHERE agr_name            = @ls_hdr-agr_name.
*            AND child_agr           = @lt_item-child_agr
*            AND wf_approval_status <> 'PENDING'.


        IF ls_hdr-create_flag = 'X'.
          LOOP AT lt_item INTO DATA(ls_new_c).
            CLEAR ls_cd.
            MOVE-CORRESPONDING ls_new_c TO ls_cd-n.
            ls_cd-n-agr_name = ls_hdr-agr_name.   " ensure key is set
            ls_cd-upd        = 'I'.
            APPEND ls_cd TO lt_cd.
          ENDLOOP.
        ELSE.                                        " CHANGE
*             inserts + updates
          LOOP AT lt_item INTO DATA(ls_new).
            READ TABLE it_snapshot INTO ls_old
                 WITH KEY child_agr = ls_new-child_agr.
            IF sy-subrc <> 0.
              CLEAR ls_cd.
              MOVE-CORRESPONDING ls_new TO ls_cd-n.
              ls_cd-n-agr_name = ls_hdr-agr_name.
              ls_cd-upd = 'I'.
              APPEND ls_cd TO lt_cd.
            ELSEIF ls_new <> ls_old.
              CLEAR ls_cd.
              MOVE-CORRESPONDING ls_new TO ls_cd-n.
              MOVE-CORRESPONDING ls_old TO ls_cd-o.
              ls_cd-n-agr_name = ls_hdr-agr_name.
              ls_cd-o-agr_name = ls_hdr-agr_name.
              ls_cd-upd = 'U'.
              APPEND ls_cd TO lt_cd.
            ENDIF.
          ENDLOOP.

*             deletes
          LOOP AT it_snapshot INTO ls_old.
            READ TABLE lt_item TRANSPORTING NO FIELDS
                 WITH KEY child_agr = ls_old-child_agr.
            IF sy-subrc <> 0.
              CLEAR ls_cd.
              MOVE-CORRESPONDING ls_old TO ls_cd-o.
              ls_cd-o-agr_name = ls_hdr-agr_name.
              ls_cd-upd = 'D'.
              APPEND ls_cd TO lt_cd.
            ENDIF.
          ENDLOOP.
        ENDIF.

        LOOP AT lt_cd INTO ls_cd.
          CALL FUNCTION 'ZCOMP_ROLE_WRITE_DOCUMENT'
            EXPORTING
              objectid                = CONV cdhdr-objectid( ls_hdr-agr_name )
              tcode                   = 'Z_ARC_RECMAN'
              utime                   = sy-uzeit
              udate                   = sy-datum
              username                = sy-uname
              object_change_indicator = lv_obj_ind
              n_zcomp_role_hdr        = ls_cd-n
              o_zcomp_role_hdr        = ls_cd-o
              upd_zcomp_role_hdr      = ls_cd-upd.
        ENDLOOP.

        "5) Run external program after commit
*        SUBMIT z_arc_recman_reminder AND RETURN.

        DATA: s_rng TYPE RANGE OF zz_owner_group.

*        s_rng = VALUE #( ( sign = 'I' option = 'EQ' low = gv_owner_group ) ).
        s_rng = VALUE #( ( sign = 'I' option = 'EQ' low = ls_hdr-owner_group ) ).

*      PERFORM send_email.

*        LOOP AT itab_1 ASSIGNING <fs_new>.
*          SELECT SINGLE wf_approval_status FROM zcomp_role_hdr
*            INTO @DATA(lv_status)
*           WHERE agr_name = @<fs_new>-agr_name
*             AND child_agr = @<fs_new>-child_agr.
*
*          IF lv_status = 'PENDING'.
*            DATA(lv_status_flag) = 'X'.
*          ENDIF.
*        ENDLOOP.

*        IF lv_status_flag EQ 'X'.
        SUBMIT z_arc_recman_reminder WITH s_rng IN s_rng
        AND RETURN.
*          MESSAGE i001(zz_arc_recman) WITH ls_hdr-agr_name.
        DATA: lv_msg1 TYPE symsgv.
        lv_msg1 = ls_hdr-agr_name.

        lo_mc->add_message(
          iv_msg_type               = 'I'               " Message Type
          iv_msg_id                 = 'ZZ_ARC_RECMAN'                 " Message Class
          iv_msg_number             =  '001'                " Message Number
*            iv_msg_text               =                  " Message Text
            iv_msg_v1                 = lv_msg1              " Message Variable
*            iv_msg_v2                 =                  " Message Variable
*            iv_msg_v3                 =                  " Message Variable
*            iv_msg_v4                 =                  " Message Variable
*            iv_error_category         =                  " Error Category
*            iv_is_leading_message     = abap_true        " Is leading message?
*            iv_entity_type            =                  " Entity type/name
*            it_key_tab                =                  " Entity key as name-value pair
*            iv_add_to_response_header = abap_false       " Flag for adding or not the message to the response header
*            iv_message_target         =                  " Target (reference) (e.g. property ID) of a message
*            it_message_target         =                  " Table of targets for more than one message targets.
*            iv_omit_target            = abap_false       " Set to TRUE if message has no target
*            iv_is_transition_message  = abap_false       " Is transition message?
*            iv_content_id             =                  " ContentID
        ).


*        ENDIF.
      ENDIF.


      IF lt_item IS NOT INITIAL.
        "Return header
        copy_data_to_ref(
          EXPORTING is_data = ls_deep
          CHANGING cr_data = er_deep_entity ).
      ELSE.
        lo_mc->add_message_text_only( iv_msg_type = 'E' iv_msg_text = 'No single role has been added in this composite role or single role is already in rejected or approved status' ).
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_mc.
      ENDIF.


    ENDIF.

  ENDMETHOD.


METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.

  TYPES:lr_agr_name_type TYPE RANGE OF agr_name,
        BEGIN OF type_output,
          status    TYPE char80,
          role      TYPE agr_name,
          role_type TYPE char80,
          text      TYPE agr_title,
          sgl_role  TYPE agr_name,
          inh_role  TYPE par_agr,
          rqst      TYPE trkorr,
          error     TYPE menu_attr,
          err_text  TYPE bapi_msg,
        END OF type_output.
  DATA : lr_agr_name_01 TYPE lr_agr_name_type, "Table 1
         lv_retc        TYPE sysubrc,
         lv_variant     TYPE raldb_vari,
         gt_output      TYPE TABLE OF type_output,
         ls_output      TYPE type_output.

  DATA: lv_agr_name      TYPE zcomp_role_hdr-agr_name,
        lv_child_agr     TYPE zcomp_role_hdr-child_agr,
        lv_type          TYPE char1,
        lv_text_1        TYPE as4text,
        lv_reject_reason TYPE zcomp_role_hdr-reject_reason,
        lv_ts            TYPE timestamp,
        lv_d             TYPE d,
        lv_t             TYPE t,
        lv_now           TYPE char14,
        ls_db            TYPE zcomp_role_hdr,
        lv_text          TYPE string,
        lv_v1            TYPE symsgv,
        lv_v1_type       TYPE symsgv,
        lt_dd07v         TYPE STANDARD TABLE OF dd07v,
        lt_rng           TYPE RANGE OF zrecman_owners-owner_group,
        lr_data          TYPE REF TO data,
        lr_data_1        TYPE REF TO data,
        ls_role          TYPE zcl_zz_arc_rec_manager_mpc=>ts_pendingapprovals.

  DATA:
    lv_role            TYPE agr_name,
    lv_s_role          TYPE child_agr,
    lv_request         TYPE bapiscts01-requestid,
    lv_task            TYPE bapiscts01-requestid,
    ls_return          TYPE bapiret2,
    ls_return2         TYPE bapiret2,
    lt_tasks           TYPE STANDARD TABLE OF bapiscts07,
    lt_tasks2          TYPE STANDARD TABLE OF bapiscts07,
    ls_task            TYPE bapiscts07,
    lt_authorlist      TYPE STANDARD TABLE OF bapiscts12,
    ls_author          TYPE bapiscts12,
    ls_zrecman_logs    TYPE zrecman_logs,
    ls_zrecman_logs_tr TYPE zrecman_logs_tr,
    lt_zrecman_logs_tr TYPE TABLE OF zrecman_logs_tr.

*  DATA: lv_max TYPE i.

  DATA:
    lt_e071  TYPE STANDARD TABLE OF e071,
    ls_e071  TYPE e071,
    lt_e071k TYPE STANDARD TABLE OF e071k.

  "Fallback read-task data
  DATA:
    lt_e070  TYPE TABLE OF e070,
    lt_e070t TYPE TABLE OF e07t,
    ls_e070  TYPE e070.

  DATA:
    lv_exists TYPE agr_name.
  DATA: lt_zcomp_role_hdr TYPE TABLE OF zcomp_role_hdr.

************Start of Code by Kanishk Arora***************************

  DATA:
  lv_role_authorized TYPE abap_bool,
  lv_role_escalated  TYPE c LENGTH 1.
  DATA lo_msg_cont TYPE REF TO /iwbep/if_message_container.
  DATA lv_role_owner TYPE zrecman_owners-owner_id.

************End of Code by Kanishk Arora*****************************

************Start of Code by Kanishk Arora***************************

DATA: lv_objectid   TYPE cdhdr-objectid,
      lv_username   TYPE cdhdr-username,
      lv_tcode      TYPE tcode,
      lv_datefrom   TYPE sydatum,
      lv_dateto     TYPE sydatum,
      lv_timefrom   TYPE syuzeit,
      lv_timeto     TYPE syuzeit,
      lv_tabname    TYPE cdpos-tabname,
      lv_fieldname  TYPE cdpos-fname,
      lv_chngind    TYPE cdpos-chngind.

************End of Code by Kanishk Arora*****************************

  FIELD-SYMBOLS <fs_role> TYPE  zcl_zz_arc_rec_manager_mpc=>ts_pendingapprovals.
  FIELD-SYMBOLS <fs_tr_hdr> TYPE zcl_zz_arc_rec_manager_mpc=>ts_transportroles.
  FIELD-SYMBOLS <fs_tr_hdr_1> TYPE zcl_zz_arc_rec_manager_mpc=>ts_transportroles.

  CASE iv_action_name.
****************************************************************
*->  Approve the Role
****************************************************************
    WHEN 'ApproveRole'.

      " Read import parameters
      READ TABLE it_parameter INTO DATA(ls_p) WITH KEY name = 'AGR_NAME'.
      IF sy-subrc = 0.
        lv_agr_name = ls_p-value.
        READ TABLE it_parameter INTO ls_p WITH KEY name = 'CHILD_AGR'.
        IF sy-subrc = 0.
          lv_child_agr = ls_p-value.
        ENDIF.
      ENDIF.

      lv_v1 = |{ lv_agr_name }|.



*-> Role Owners and Emails address Mapping table
*      CALL FUNCTION 'DD_DOMVALUES_GET'
*        EXPORTING
*          domname   = 'ZZ_OWNER_GROUP'
*          langu     = sy-langu
*        TABLES
*          dd07v_tab = lt_dd07v.
*
*      LOOP AT lt_dd07v INTO DATA(ls_dd07v) WHERE domvalue_l IS NOT INITIAL.
*        IF lv_agr_name CS ls_dd07v-domvalue_l.
*          APPEND VALUE #( sign   = 'I'
*                          option = 'CP'
*                          low    = |*{ ls_dd07v-domvalue_l }*| ) TO lt_rng.
*        ENDIF.
*      ENDLOOP.
*
*      SELECT owner_id
*        FROM zrecman_owners
*        INTO  @DATA(lv_role_owner)
*        WHERE owner_group IN @lt_rng.
*      ENDSELECT.
*      IF sy-subrc NE 0.
*        DATA(lo_msg_cont) = mo_context->get_message_container( ).
*        lo_msg_cont->add_message(
*          iv_msg_type   = 'E'
*          iv_msg_id     = 'ZZ_ARC_RECMAN'
*          iv_msg_number = '013'   "Not authorized to approve this role & linked with User &
*          iv_msg_v1     = lv_v1 ).
*
*        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
*          EXPORTING
*            message_container = lo_msg_cont.
*      ENDIF.

*->  Validate current record + status

      SELECT SINGLE * FROM zcomp_role_hdr INTO @ls_db
        WHERE agr_name  = @lv_agr_name
          AND child_agr = @lv_child_agr.

      IF sy-subrc <> 0.   "Role & not found
        lo_msg_cont = mo_context->get_message_container( ).
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_RECMAN'
          iv_msg_number = '022'
          iv_msg_v1     = lv_v1 ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.
      ENDIF.

*-> Role not in PENDING status
      IF ls_db-wf_approval_status <> 'PENDING'.
        lo_msg_cont = mo_context->get_message_container( ).
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_RECMAN'
          iv_msg_number = '023'
          iv_msg_v1     = lv_v1 ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.
      ENDIF.

**********Start of Code by Kanishk Arora **********************

      CLEAR:
  lv_role_authorized,
  lv_role_escalated.

SELECT SINGLE escalation_sent
  FROM zrecman_reminder
  INTO @lv_role_escalated
  WHERE agr_name  = @ls_db-agr_name
    AND child_agr = @ls_db-child_agr.

lv_role_authorized =
  zcl_arc_owngrp_service=>is_user_in_owner_group(
    iv_user        = sy-uname
    iv_owner_group = ls_db-owner_group
    iv_escalated   = xsdbool(
                       lv_role_escalated = 'X' ) ).

IF lv_role_authorized = abap_false.

  lo_msg_cont = mo_context->get_message_container( ).

  lo_msg_cont->add_message(
    iv_msg_type   = 'E'
    iv_msg_id     = 'ZZ_ARC_RECMAN'
    iv_msg_number = '013'
    iv_msg_v1     = lv_v1 ).

  RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
    EXPORTING
      message_container = lo_msg_cont.

ENDIF.

**********End of Code by Kanishk Arora************************

*-> Lock Object
      CALL FUNCTION 'ENQUEUE_EZAGR_AGRS'
        EXPORTING
          mandt          = sy-mandt
          agr_name       = lv_agr_name
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.

      IF sy-subrc <> 0.
        CASE sy-subrc.
*-> Data record is currently locked by another session
          WHEN 1.
            lo_msg_cont = mo_context->get_message_container( ).
            lo_msg_cont->add_message(
              iv_msg_type   = 'E'
              iv_msg_id     = 'ZZ_ARC_RECMAN'
              iv_msg_number = '008' ).

            RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
              EXPORTING
                message_container = lo_msg_cont.

*-> System failure while trying to lock role
          WHEN 2.
            lo_msg_cont = mo_context->get_message_container( ).
            lo_msg_cont->add_message(
              iv_msg_type   = 'E'
              iv_msg_id     = 'ZZ_ARC_RECMAN'
              iv_msg_number = '011' ).

            RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
              EXPORTING
                message_container = lo_msg_cont.

          WHEN OTHERS.
            RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception.
        ENDCASE.
      ENDIF.

*-> Server timestamp
      GET TIME STAMP FIELD lv_ts.
      CONVERT TIME STAMP lv_ts TIME ZONE 'UTC' INTO DATE lv_d TIME lv_t.
      lv_now = |{ lv_d }{ lv_t }|.

*-> Fetch Role Description
      IF ls_db-child_agr_descr IS INITIAL.
        SELECT SINGLE text FROM agr_texts INTO @DATA(lv_agr_text)
          WHERE agr_name = @ls_db-child_agr
          AND spras = @sy-langu.
        IF sy-subrc EQ 0.
          ls_db-child_agr_descr = lv_agr_text.
        ENDIF.
      ENDIF.

*-> Update DB

      ls_db-wf_approval_status = 'APPROVED'.
      ls_db-approved_at        = lv_now.  " set on approve
      ls_db-approver           = sy-uname.
      MOVE-CORRESPONDING ls_db TO ls_zrecman_logs.
      ls_zrecman_logs-system_id       = sy-sysid.

      MODIFY zrecman_logs FROM ls_zrecman_logs.
      COMMIT WORK.

      MODIFY zcomp_role_hdr FROM ls_db.
      COMMIT WORK.

      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception.
      ENDIF.



*-> Fill ls_role
      SELECT SINGLE *
        FROM zcomp_role_hdr
        INTO CORRESPONDING FIELDS OF @ls_role
        WHERE agr_name  = @lv_agr_name
          AND child_agr = @lv_child_agr.

*-> Create data and assign
      CREATE DATA lr_data TYPE zcl_zz_arc_rec_manager_mpc=>ts_pendingapprovals.
      ASSIGN lr_data->* TO <fs_role>.
      <fs_role> = ls_role.

      er_data = lr_data.

*->  Unlock the object
      CALL FUNCTION 'DEQUEUE_EZAGR_AGRS'
        EXPORTING
*         mode_agr_agrs = 'E'         " Lock mode for table AGR_AGRS
          mandt    = sy-mandt         " Enqueue argument 01
          agr_name = lv_agr_name.    " Enqueue argument 02
****************************************************************
*->  Reject the Role
****************************************************************
    WHEN 'RejectRole'.
      " Read import parameters
      READ TABLE it_parameter INTO ls_p WITH KEY name = 'AGR_NAME'.
      IF sy-subrc = 0.
        lv_agr_name = ls_p-value.
        READ TABLE it_parameter INTO ls_p WITH KEY name = 'CHILD_AGR'.
        IF sy-subrc = 0.
          lv_child_agr = ls_p-value.
          READ TABLE it_parameter INTO ls_p WITH KEY name = 'REJECT_REASON'.
          IF sy-subrc = 0.
            lv_reject_reason = ls_p-value.
          ENDIF.
        ENDIF.
      ENDIF.
      IF lv_agr_name IS INITIAL.
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_FIREFIGHTER'     " Message class
          iv_msg_number = '010'         " Message number
          iv_msg_v1     = 'Composite Role is expected in HTTP URI' " or split into v1..v4 as needed
                            ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.
      ENDIF.
      IF lv_child_agr IS INITIAL.
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_FIREFIGHTER'     " Message class
          iv_msg_number = '010'         " Message number
          iv_msg_v1     = 'Single Role is expected in HTTP URI' " or split into v1..v4 as needed
                            ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.
      ENDIF.
      IF lv_reject_reason IS INITIAL.
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_FIREFIGHTER'     " Message class
          iv_msg_number = '010'         " Message number
          iv_msg_v1     = 'Reject Reason is expected in HTTP URI' " or split into v1..v4 as needed
                            ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.
      ENDIF.

      lv_v1 = |{ lv_agr_name }|.
*-> Role Owners and Emails address Mapping table
*      CALL FUNCTION 'DD_DOMVALUES_GET'
*        EXPORTING
*          domname   = 'ZZ_OWNER_GROUP'
*          langu     = sy-langu
*        TABLES
*          dd07v_tab = lt_dd07v.
*
*      LOOP AT lt_dd07v INTO ls_dd07v WHERE domvalue_l IS NOT INITIAL.
*        IF lv_agr_name CS ls_dd07v-domvalue_l.
*          APPEND VALUE #( sign   = 'I'
*                          option = 'CP'
*                          low    = |*{ ls_dd07v-domvalue_l }*| ) TO lt_rng.
*        ENDIF.
*      ENDLOOP.
*
*      SELECT owner_id
*        FROM zrecman_owners
*        INTO @lv_role_owner
*        WHERE owner_group IN @lt_rng.
*      ENDSELECT.
*      IF sy-subrc NE 0.
*        lo_msg_cont = mo_context->get_message_container( ).
*        lo_msg_cont->add_message(
*          iv_msg_type   = 'E'
*          iv_msg_id     = 'ZZ_ARC_RECMAN'
*          iv_msg_number = '013'   "Not authorized to approve this role & linked with User &
*          iv_msg_v1     = lv_v1 ).
*
*        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
*          EXPORTING
*            message_container = lo_msg_cont.
*      ENDIF.

*->  Validate current record + status
*      SELECT SINGLE * FROM zcomp_role_hdr INTO @ls_db
*        WHERE agr_name  = @lv_agr_name.
**          AND child_agr = @lv_child_agr.


*********Start of Code by Kanishk Arora ******************

SELECT SINGLE *
  FROM zcomp_role_hdr
  INTO @ls_db
  WHERE agr_name  = @lv_agr_name
    AND child_agr = @lv_child_agr.

**********End of Code by Kanishk Arora********************



      IF sy-subrc <> 0.   "Role & not found
        lo_msg_cont = mo_context->get_message_container( ).
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_RECMAN'
          iv_msg_number = '022'
          iv_msg_v1     = lv_v1 ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.
      ENDIF.

**************Start of Code by Kanishk Arora***************************

      CLEAR:
  lv_role_authorized,
  lv_role_escalated.

SELECT SINGLE escalation_sent
  FROM zrecman_reminder
  INTO @lv_role_escalated
  WHERE agr_name  = @ls_db-agr_name
    AND child_agr = @ls_db-child_agr.

lv_role_authorized =
  zcl_arc_owngrp_service=>is_user_in_owner_group(
    iv_user        = sy-uname
    iv_owner_group = ls_db-owner_group
    iv_escalated   = xsdbool(
                       lv_role_escalated = 'X' ) ).

IF lv_role_authorized = abap_false.

  lo_msg_cont = mo_context->get_message_container( ).

  lo_msg_cont->add_message(
    iv_msg_type   = 'E'
    iv_msg_id     = 'ZZ_ARC_RECMAN'
    iv_msg_number = '013'
    iv_msg_v1     = lv_v1 ).

  RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
    EXPORTING
      message_container = lo_msg_cont.

ENDIF.

**************End of Code by Kanishk Arora*****************************

*-> Role not in PENDING status
*      IF ls_db-wf_approval_status <> 'PENDING'.
*        lo_msg_cont = mo_context->get_message_container( ).
*        lo_msg_cont->add_message(
*          iv_msg_type   = 'E'
*          iv_msg_id     = 'ZZ_ARC_RECMAN'
*          iv_msg_number = '023'
*          iv_msg_v1     = lv_v1 ).
*
*        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
*          EXPORTING
*            message_container = lo_msg_cont.
*      ENDIF.

*-> Lock Object
      CALL FUNCTION 'ENQUEUE_EZAGR_AGRS'
        EXPORTING
          mandt          = sy-mandt
          agr_name       = lv_agr_name
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.

      IF sy-subrc <> 0.
        CASE sy-subrc.
*-> Data record is currently locked by another session
          WHEN 1.
            lo_msg_cont = mo_context->get_message_container( ).
            lo_msg_cont->add_message(
              iv_msg_type   = 'E'
              iv_msg_id     = 'ZZ_ARC_RECMAN'
              iv_msg_number = '008' ).

            RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
              EXPORTING
                message_container = lo_msg_cont.

*-> System failure while trying to lock role
          WHEN 2.
            lo_msg_cont = mo_context->get_message_container( ).
            lo_msg_cont->add_message(
              iv_msg_type   = 'E'
              iv_msg_id     = 'ZZ_ARC_RECMAN'
              iv_msg_number = '011' ).

            RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
              EXPORTING
                message_container = lo_msg_cont.

          WHEN OTHERS.
            RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception.
        ENDCASE.
      ENDIF.


*-> Server timestamp
      GET TIME STAMP FIELD lv_ts.
      CONVERT TIME STAMP lv_ts TIME ZONE 'UTC' INTO DATE lv_d TIME lv_t.
      lv_now = |{ lv_d }{ lv_t }|.

*-> Fetch Role Description
      IF ls_db-child_agr_descr IS INITIAL.
        SELECT SINGLE text FROM agr_texts INTO @lv_agr_text
          WHERE agr_name = @ls_db-child_agr
          AND spras = @sy-langu.
        IF sy-subrc EQ 0.
          ls_db-child_agr_descr = lv_agr_text.
        ENDIF.
      ENDIF.

***      UPDATE zcomp_role_hdr
***         SET wf_approval_status = 'REJECTED',
***             approved_at        = @space,
***             approver           = @sy-uname,
***             changed_at         = @space,
***             rejected_at        = @lv_ts,
***             reject_reason      = @lv_reject_reason
***       WHERE agr_name  = @lv_agr_name
***         AND child_agr = @lv_child_agr.
***      COMMIT WORK.

*-> Update DB

      ls_db-wf_approval_status = 'REJECTED'.
      ls_db-rejected_at        = lv_now.  " set on reject
      ls_db-reject_reason      = lv_reject_reason.  " set on reject reason
      ls_db-approver           = sy-uname.
      MOVE-CORRESPONDING ls_db TO ls_zrecman_logs.
      ls_zrecman_logs-system_id       = sy-sysid.

      MODIFY zrecman_logs FROM ls_zrecman_logs.
      COMMIT WORK.

      MODIFY zcomp_role_hdr FROM ls_db.
      COMMIT WORK.

      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception.
      ENDIF.

*-> Fill ls_role
      SELECT SINGLE *
        FROM zcomp_role_hdr
        INTO CORRESPONDING FIELDS OF @ls_role
        WHERE agr_name  = @lv_agr_name
          AND child_agr = @lv_child_agr.

*-> Create data and assign
      CREATE DATA lr_data TYPE zcl_zz_arc_rec_manager_mpc=>ts_pendingapprovals.
      ASSIGN lr_data->* TO <fs_role>.
      <fs_role> = ls_role.

      er_data = lr_data.

*->  Unlock the object
      CALL FUNCTION 'DEQUEUE_EZAGR_AGRS'
        EXPORTING
*         mode_agr_agrs = 'E'         " Lock mode for table AGR_AGRS
          mandt    = sy-mandt         " Enqueue argument 01
          agr_name = lv_agr_name.    " Enqueue argument 02


****************************************************************
*->  Transport the Role
****************************************************************
    WHEN 'TransportRole'.
      " Read import parameters
      READ TABLE it_parameter INTO ls_p WITH KEY name = 'AGR_NAME'.
      IF sy-subrc = 0.
        lv_agr_name = ls_p-value.
        READ TABLE it_parameter INTO ls_p WITH KEY name = 'TEXT'.
        IF sy-subrc = 0.
          lv_text_1 = ls_p-value.
          READ TABLE it_parameter INTO ls_p WITH KEY name = 'TYPE'.
          IF sy-subrc = 0.
            lv_type = ls_p-value.
          ENDIF.
        ENDIF.
      ENDIF.

      "Validate request type
      TRANSLATE lv_type TO UPPER CASE.
      IF lv_type <> 'W' AND lv_type <> 'K'.
*          MESSAGE 'p_type must be W (Workbench) or K (Customizing)' TYPE 'E'.
        lv_v1_type = lv_type.
        lo_msg_cont = mo_context->get_message_container( ).
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_RECMAN'
          iv_msg_number = '004'   "lv_type must be W (Workbench) or K (Customizing)
          iv_msg_v1     = lv_v1_type ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.
      ENDIF.

      "Normalize role name
      lv_role = lv_agr_name.
      TRANSLATE lv_role TO UPPER CASE.

      lv_s_role = lv_child_agr.
      TRANSLATE lv_s_role TO UPPER CASE.

      lv_v1 = |{ lv_agr_name }|.

*-> Role Owners and Emails address Mapping table
      CALL FUNCTION 'DD_DOMVALUES_GET'
        EXPORTING
          domname   = 'ZZ_OWNER_GROUP'
          langu     = sy-langu
        TABLES
          dd07v_tab = lt_dd07v.

      LOOP AT lt_dd07v INTO DATA(ls_dd07v) WHERE domvalue_l IS NOT INITIAL.
        IF lv_agr_name CS ls_dd07v-domvalue_l.
          APPEND VALUE #( sign   = 'I'
                          option = 'CP'
                          low    = |*{ ls_dd07v-domvalue_l }*| ) TO lt_rng.
        ENDIF.
      ENDLOOP.

      SELECT owner_id
        FROM zrecman_owners
        INTO @lv_role_owner
        WHERE owner_group IN @lt_rng.
      ENDSELECT.
      IF sy-subrc NE 0.
        lo_msg_cont = mo_context->get_message_container( ).
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_RECMAN'
          iv_msg_number = '013'   "Not authorized to approve this role & linked with User &
          iv_msg_v1     = lv_v1 ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.
      ENDIF.

*->  Validate current record + status
      SELECT SINGLE * FROM zcomp_role_hdr INTO @ls_db
        WHERE agr_name  = @lv_agr_name.
*          AND child_agr = @lv_child_agr.

      IF sy-subrc <> 0.   "Role & not found
        lo_msg_cont = mo_context->get_message_container( ).
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_RECMAN'
          iv_msg_number = '022'
          iv_msg_v1     = lv_v1 ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.
      ENDIF.

*-> Lock Object
      CALL FUNCTION 'ENQUEUE_EZAGR_AGRS'
        EXPORTING
          mandt          = sy-mandt
          agr_name       = lv_agr_name
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.

      IF sy-subrc <> 0.
        CASE sy-subrc.
*-> Data record is currently locked by another session
          WHEN 1.
            lo_msg_cont = mo_context->get_message_container( ).
            lo_msg_cont->add_message(
              iv_msg_type   = 'E'
              iv_msg_id     = 'ZZ_ARC_RECMAN'
              iv_msg_number = '008' ).

            RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
              EXPORTING
                message_container = lo_msg_cont.

*-> System failure while trying to lock role
          WHEN 2.
            lo_msg_cont = mo_context->get_message_container( ).
            lo_msg_cont->add_message(
              iv_msg_type   = 'E'
              iv_msg_id     = 'ZZ_ARC_RECMAN'
              iv_msg_number = '011' ).

            RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
              EXPORTING
                message_container = lo_msg_cont.

          WHEN OTHERS.
            RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception.
        ENDCASE.
      ENDIF.

*-> Server timestamp
      GET TIME STAMP FIELD lv_ts.
      CONVERT TIME STAMP lv_ts TIME ZONE 'UTC' INTO DATE lv_d TIME lv_t.
      lv_now = |{ lv_d }{ lv_t }|.


      SELECT SINGLE * FROM zcomp_role_hdr INTO @DATA(ls_zcomp_role_hdr)
      WHERE agr_name EQ @lv_agr_name.
*-> Fetch Role Description
      IF ls_zcomp_role_hdr-child_agr_descr IS INITIAL.
        CLEAR lv_agr_text.
        SELECT SINGLE text FROM agr_texts INTO @lv_agr_text
          WHERE agr_name = @ls_db-child_agr
          AND spras = @sy-langu.
        IF sy-subrc EQ 0.
          ls_zcomp_role_hdr-child_agr_descr = lv_agr_text.
        ENDIF.
      ENDIF.


*************************************************************************
*-> Don't Transport Single Role, when status is 'REJECTED' / 'PENDING'
*************************************************************************
      CLEAR: lt_zrecman_logs_tr, lt_zcomp_role_hdr.
      SELECT * FROM zcomp_role_hdr INTO TABLE @lt_zcomp_role_hdr
         WHERE agr_name = @lv_agr_name
           AND wf_approval_status NE 'APPROVED'.
      FIELD-SYMBOLS: <fs_zrecman_logs_tr> TYPE zrecman_logs_tr.
      IF sy-subrc EQ 0.
        LOOP AT lt_zcomp_role_hdr ASSIGNING FIELD-SYMBOL(<fs_zcomp_role_hdr>).
          APPEND INITIAL LINE TO lt_zrecman_logs_tr ASSIGNING <fs_zrecman_logs_tr>.
          MOVE-CORRESPONDING <fs_zcomp_role_hdr> TO <fs_zrecman_logs_tr>.
          <fs_zrecman_logs_tr>-system_id          = sy-sysid.
          <fs_zrecman_logs_tr>-blocked_role      = <fs_zcomp_role_hdr>-child_agr.
          <fs_zrecman_logs_tr>-blocked_timestamp = lv_now.
          <fs_zrecman_logs_tr>-blocked_by        = sy-uname.
        ENDLOOP.
      ENDIF.

      MODIFY zrecman_logs_tr FROM TABLE lt_zrecman_logs_tr.
      COMMIT WORK.

*-> Fill ls_role
      SELECT SINGLE *
        FROM zrecman_logs_tr
        INTO @DATA(ls_tr_hdr)
        WHERE agr_name  = @lv_agr_name
          AND child_agr = @lv_child_agr.

*-> Create data and assign
      CREATE DATA lr_data TYPE zcl_zz_arc_rec_manager_mpc=>ts_transportroles.
      ASSIGN lr_data->* TO <fs_tr_hdr>.
      <fs_tr_hdr> = ls_tr_hdr.

      er_data = lr_data.

*->  Unlock the object
      CALL FUNCTION 'DEQUEUE_EZAGR_AGRS'
        EXPORTING
*         mode_agr_agrs = 'E'         " Lock mode for table AGR_AGRS
          mandt    = sy-mandt         " Enqueue argument 01
          agr_name = lv_agr_name.    " Enqueue argument 02

******************************************************************
*-> Transport Single Role, when status is 'APPROVED'
******************************************************************
      CLEAR: lt_zrecman_logs_tr, lt_zcomp_role_hdr.
      SELECT * FROM zcomp_role_hdr INTO TABLE @lt_zcomp_role_hdr
         WHERE agr_name = @lv_agr_name
           AND wf_approval_status = 'APPROVED'.

      IF sy-subrc EQ 0.
        "Prepare task owner list
        CLEAR: lt_authorlist, ls_author.
        ls_author-task_owner = sy-uname.
        APPEND ls_author TO lt_authorlist.

        "1) Create TR
        CLEAR: lv_request, ls_return, lt_tasks.
        CALL FUNCTION 'BAPI_CTREQUEST_CREATE'
          EXPORTING
            author       = sy-uname
            text         = lv_text_1
            request_type = lv_type               "W or K
          IMPORTING
            requestid    = lv_request
            return       = ls_return
          TABLES
            authorlist   = lt_authorlist
            task_list    = lt_tasks.

        IF ls_return-type = 'E' OR ls_return-type = 'A'.
          MESSAGE |TR creation failed: { ls_return-message }| TYPE 'E'.
        ENDIF.

        IF lv_request IS INITIAL.
          MESSAGE 'TR creation failed: Request ID is initial' TYPE 'E'.
        ENDIF.

        CLEAR lv_task.

        "2a) Use task returned by create BAPI (if any)
        READ TABLE lt_tasks INTO ls_task INDEX 1.
        IF sy-subrc = 0 AND ls_task-taskid IS NOT INITIAL.
          lv_task = ls_task-taskid.
        ENDIF.

        "2b) Fallback: explicitly create tasks
        IF lv_task IS INITIAL.
          CLEAR: ls_return2, lt_tasks2.
          CALL FUNCTION 'BAPI_CTREQUEST_CREATE_TASKS'
            EXPORTING
              requestid  = lv_request
            IMPORTING
              return     = ls_return2
            TABLES
              authorlist = lt_authorlist
              task_list  = lt_tasks2.

          IF ls_return2-type = 'E' OR ls_return2-type = 'A'.
            MESSAGE |Task creation failed: { ls_return2-message }| TYPE 'E'.
          ENDIF.

          READ TABLE lt_tasks2 INTO ls_task INDEX 1.
          IF sy-subrc = 0 AND ls_task-taskid IS NOT INITIAL.
            lv_task = ls_task-taskid.
          ENDIF.
        ENDIF.

        "2c) Final fallback: read tasks from request
        IF lv_task IS INITIAL.
          CLEAR: lt_e070, lt_e070t.
          CALL FUNCTION 'TR_READ_REQUEST_WITH_TASKS'
            EXPORTING
              iv_trkorr      = lv_request
            TABLES
              et_e070        = lt_e070
              et_e070t       = lt_e070t
            EXCEPTIONS
              invalid_input  = 1
              not_exist_e070 = 2
              OTHERS         = 3.

          IF sy-subrc <> 0.
            MESSAGE |TR created ({ lv_request }) but could not read tasks via TR_READ_REQUEST_WITH_TASKS| TYPE 'E'.
          ENDIF.

          "Pick first task (usually TRFUNCTION = 'S') belonging to this request
          LOOP AT lt_e070 INTO ls_e070 WHERE strkorr = lv_request.
            IF ls_e070-trfunction = 'S' AND ls_e070-trkorr IS NOT INITIAL.
              lv_task = ls_e070-trkorr.
              EXIT.
            ENDIF.
          ENDLOOP.
        ENDIF.

        IF lv_task IS INITIAL.
          MESSAGE |TR created ({ lv_request }) but no task could be determined/created| TYPE 'E'.
        ENDIF.

        "3) Build object entry for role: R3TR / ACGR / <AGR_NAME>
        CLEAR: lt_e071, ls_e071, lt_e071k.

        SELECT SINGLE MAX( as4pos ) FROM e071 INTO @DATA(lv_max)
          WHERE trkorr = @lv_task
           AND pgmid = 'R3TR'
           AND object = 'ACGR'.

        LOOP AT lt_zcomp_role_hdr ASSIGNING <fs_zcomp_role_hdr>.
          ADD 1 TO lv_max.
          APPEND INITIAL LINE TO lt_e071 ASSIGNING FIELD-SYMBOL(<fs_e071>).
          <fs_e071>-as4pos   =  lv_max.
          <fs_e071>-trkorr   =  lv_task.
          <fs_e071>-pgmid    = 'R3TR'.
          <fs_e071>-object   = 'ACGR'.
          <fs_e071>-obj_name = <fs_zcomp_role_hdr>-child_agr.
        ENDLOOP.

        MODIFY e071 FROM TABLE lt_e071.
        COMMIT WORK.

        LOOP AT lt_zcomp_role_hdr ASSIGNING <fs_zcomp_role_hdr>.
          APPEND INITIAL LINE TO lt_zrecman_logs_tr ASSIGNING <fs_zrecman_logs_tr>.
          MOVE-CORRESPONDING <fs_zcomp_role_hdr> TO <fs_zrecman_logs_tr>.
          <fs_zrecman_logs_tr>-system_id    = sy-sysid.
          <fs_zrecman_logs_tr>-transport_no = lv_task.
        ENDLOOP.

        MODIFY zrecman_logs_tr FROM TABLE lt_zrecman_logs_tr.
        COMMIT WORK.

*-> Fill ls_role
        SELECT SINGLE *
          FROM zrecman_logs_tr
          INTO @DATA(ls_tr_hdr_1)
          WHERE agr_name  = @lv_agr_name
            AND child_agr = @lv_child_agr.

*-> Create data and assign
        CREATE DATA lr_data_1 TYPE zcl_zz_arc_rec_manager_mpc=>ts_transportroles.
        ASSIGN lr_data_1->* TO <fs_tr_hdr_1>.
        <fs_tr_hdr_1> = ls_tr_hdr_1.

        er_data = lr_data_1.

*->  Unlock the object
        CALL FUNCTION 'DEQUEUE_EZAGR_AGRS'
          EXPORTING
*           mode_agr_agrs = 'E'         " Lock mode for table AGR_AGRS
            mandt    = sy-mandt         " Enqueue argument 01
            agr_name = lv_agr_name.    " Enqueue argument 02
      ENDIF.

      WHEN 'ApproveOwnerGroupRequest'.

  DATA: lv_req_id TYPE sysuuid_x16.

  READ TABLE it_parameter INTO ls_p
    WITH KEY name = 'ReqId'.

  IF sy-subrc = 0.
    lv_req_id = ls_p-value.
  ENDIF.

  zcl_arc_owngrp_service=>approve_request(
    iv_req_id = lv_req_id
    iv_user   = sy-uname ).

  DATA:
  ls_og TYPE zcl_zz_arc_rec_manager_mpc=>ts_ownergroupapproval.

FIELD-SYMBOLS:
  <fs_og> TYPE zcl_zz_arc_rec_manager_mpc=>ts_ownergroupapproval.

SELECT SINGLE *
  FROM zcomp_owngrp_req
  INTO CORRESPONDING FIELDS OF @ls_og
  WHERE req_id = @lv_req_id.

CREATE DATA lr_data TYPE zcl_zz_arc_rec_manager_mpc=>ts_ownergroupapproval.

ASSIGN lr_data->* TO <fs_og>.

<fs_og> = ls_og.

er_data = lr_data.

  WHEN 'RejectOwnerGroupRequest'.

  DATA:
    lv_req_id_2           TYPE sysuuid_x16,
    lv_og_reject_reason   TYPE zcomp_owngrp_req-reject_reason.

  READ TABLE it_parameter INTO ls_p
    WITH KEY name = 'ReqId'.

  IF sy-subrc = 0.
    lv_req_id_2 = ls_p-value.
  ENDIF.

  READ TABLE it_parameter INTO ls_p
    WITH KEY name = 'RejectReason'.

  IF sy-subrc = 0.
    lv_og_reject_reason = ls_p-value.
  ENDIF.

  zcl_arc_owngrp_service=>reject_request(
    iv_req_id = lv_req_id_2
    iv_user   = sy-uname
    iv_reason = lv_og_reject_reason ).

  DATA:
  ls_og2 TYPE zcl_zz_arc_rec_manager_mpc=>ts_ownergroupapproval.

FIELD-SYMBOLS:
  <fs_og2> TYPE zcl_zz_arc_rec_manager_mpc=>ts_ownergroupapproval.

SELECT SINGLE *
  FROM zcomp_owngrp_req
  INTO CORRESPONDING FIELDS OF @ls_og2
  WHERE req_id = @lv_req_id_2.

CREATE DATA lr_data TYPE zcl_zz_arc_rec_manager_mpc=>ts_ownergroupapproval.

ASSIGN lr_data->* TO <fs_og2>.

<fs_og2> = ls_og2.

er_data = lr_data.



************** Start of Code by Kanishk Arora *************

WHEN 'GetAuditReport'.

  DATA:
  lt_result TYPE zcl_zz_arc_rec_manager_mpc=>tt_auditreport,
  ls_result TYPE zcl_zz_arc_rec_manager_mpc=>ts_auditreport.

FIELD-SYMBOLS:
  <fs_result> TYPE zcl_zz_arc_rec_manager_mpc=>ts_auditreport.

  READ TABLE it_parameter INTO ls_p WITH KEY name = 'ObjectId'.
IF sy-subrc = 0.
  lv_objectid = ls_p-value.
ENDIF.

READ TABLE it_parameter INTO ls_p WITH KEY name = 'UserName'.
IF sy-subrc = 0.
  lv_username = ls_p-value.
ENDIF.

READ TABLE it_parameter INTO ls_p WITH KEY name = 'Tcode'.
IF sy-subrc = 0.
  lv_tcode = ls_p-value.
ENDIF.

READ TABLE it_parameter INTO ls_p WITH KEY name = 'DateFrom'.
IF sy-subrc = 0.
  lv_datefrom = ls_p-value.
ENDIF.

READ TABLE it_parameter INTO ls_p WITH KEY name = 'DateTo'.
IF sy-subrc = 0.
  lv_dateto = ls_p-value.
ENDIF.

READ TABLE it_parameter INTO ls_p WITH KEY name = 'TimeFrom'.
IF sy-subrc = 0.
  lv_timefrom = ls_p-value.
ENDIF.

READ TABLE it_parameter INTO ls_p WITH KEY name = 'TimeTo'.
IF sy-subrc = 0.
  lv_timeto = ls_p-value.
ENDIF.

READ TABLE it_parameter INTO ls_p WITH KEY name = 'TabName'.
IF sy-subrc = 0.
  lv_tabname = ls_p-value.
ENDIF.

READ TABLE it_parameter INTO ls_p WITH KEY name = 'FieldName'.
IF sy-subrc = 0.
  lv_fieldname = ls_p-value.
ENDIF.

READ TABLE it_parameter INTO ls_p WITH KEY name = 'ChangeType'.
IF sy-subrc = 0.
  lv_chngind = ls_p-value.
ENDIF.

IF lv_datefrom IS INITIAL AND lv_dateto IS INITIAL.

  lo_msg_cont = me->mo_context->get_message_container( ).

  lo_msg_cont->add_message_text_only(
    iv_msg_type = 'E'
    iv_msg_text = 'Please provide at least a Change Date range.'
  ).

  RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
    EXPORTING
      message_container = lo_msg_cont.

ENDIF.

DATA: lt_cdhdr TYPE TABLE OF cdhdr,
      lt_cdpos TYPE TABLE OF cdpos.

DATA: lr_user    TYPE RANGE OF sy-uname,
      lr_tcode   TYPE RANGE OF sy-tcode,
      lr_object  TYPE RANGE OF cdhdr-objectid,
      lr_tabname TYPE RANGE OF cdpos-tabname,
      lr_field   TYPE RANGE OF cdpos-fname,
      lr_change  TYPE RANGE OF cdpos-chngind.

DATA: lt_r_date TYPE RANGE OF cdhdr-udate,
      lt_r_time TYPE RANGE OF cdhdr-utime.

IF lv_username IS NOT INITIAL.
  lr_user = VALUE #( (
      sign = 'I'
      option = 'EQ'
      low = lv_username ) ).
ENDIF.

IF lv_tcode IS NOT INITIAL.
  lr_tcode = VALUE #( (
      sign = 'I'
      option = 'EQ'
      low = lv_tcode ) ).
ENDIF.

IF lv_objectid IS NOT INITIAL.
  lr_object = VALUE #( (
      sign = 'I'
      option = 'EQ'
      low = lv_objectid ) ).
ENDIF.

IF lv_tabname IS NOT INITIAL.
  lr_tabname = VALUE #( (
      sign = 'I'
      option = 'EQ'
      low = lv_tabname ) ).
ENDIF.

IF lv_fieldname IS NOT INITIAL.
  lr_field = VALUE #( (
      sign = 'I'
      option = 'EQ'
      low = lv_fieldname ) ).
ENDIF.

IF lv_chngind IS NOT INITIAL.
  lr_change = VALUE #( (
      sign = 'I'
      option = 'EQ'
      low = lv_chngind ) ).
ENDIF.

IF lv_datefrom IS NOT INITIAL OR lv_dateto IS NOT INITIAL.

  APPEND VALUE #(
      sign = 'I'
      option = COND #(
          WHEN lv_datefrom IS NOT INITIAL
           AND lv_dateto IS NOT INITIAL THEN 'BT'
          WHEN lv_datefrom IS NOT INITIAL THEN 'GE'
          ELSE 'LE' )
      low = lv_datefrom
      high = lv_dateto ) TO lt_r_date.

ENDIF.

IF lv_timefrom IS NOT INITIAL OR lv_timeto IS NOT INITIAL.

  APPEND VALUE #(
      sign = 'I'
      option = COND #(
          WHEN lv_timefrom IS NOT INITIAL
           AND lv_timeto IS NOT INITIAL THEN 'BT'
          WHEN lv_timefrom IS NOT INITIAL THEN 'GE'
          ELSE 'LE' )
      low = lv_timefrom
      high = lv_timeto ) TO lt_r_time.

ENDIF.

SELECT *
  INTO TABLE @lt_cdhdr
  FROM cdhdr
 WHERE objectid IN @lr_object
   AND username IN @lr_user
   AND tcode    IN @lr_tcode
   AND udate    IN @lt_r_date
   AND utime    IN @lt_r_time.

  IF sy-subrc <> 0.

  lo_msg_cont = me->mo_context->get_message_container( ).

  lo_msg_cont->add_message_text_only(
      iv_msg_type = 'E'
      iv_msg_text = 'No Data found'
  ).

  RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
    EXPORTING
      message_container = lo_msg_cont.

ENDIF.

SORT lt_cdhdr BY objectclas objectid changenr.

SELECT *
  INTO TABLE @lt_cdpos
  FROM cdpos
  FOR ALL ENTRIES IN @lt_cdhdr
 WHERE objectclas = @lt_cdhdr-objectclas
   AND objectid   = @lt_cdhdr-objectid
   AND changenr   = @lt_cdhdr-changenr
   AND tabname    IN @lr_tabname
   AND fname      IN @lr_field
   AND chngind    IN @lr_change.

  IF sy-subrc <> 0.

  lo_msg_cont = me->mo_context->get_message_container( ).

  lo_msg_cont->add_message_text_only(
      iv_msg_type = 'E'
      iv_msg_text = 'No Data found'
  ).

  RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
    EXPORTING
      message_container = lo_msg_cont.

ENDIF.

SORT lt_cdpos BY objectclas objectid changenr.

LOOP AT lt_cdhdr INTO DATA(ls_cdhdr).

  LOOP AT lt_cdpos INTO DATA(ls_cdpos)
       WHERE objectclas = ls_cdhdr-objectclas
         AND objectid   = ls_cdhdr-objectid
         AND changenr   = ls_cdhdr-changenr.

    CLEAR ls_result.

    ls_result-username   = ls_cdhdr-username.
    ls_result-objectclas = ls_cdhdr-objectclas.
    ls_result-objectid   = ls_cdhdr-objectid.
    ls_result-tcode      = ls_cdhdr-tcode.
    ls_result-udate = |{ ls_cdhdr-udate DATE = USER }|.
ls_result-utime = |{ ls_cdhdr-utime TIME = USER }|.
    ls_result-changenr   = ls_cdhdr-changenr.

    ls_result-tabname    = ls_cdpos-tabname.
    ls_result-fname      = ls_cdpos-fname.
    ls_result-tabkey     = ls_cdpos-tabkey.
    ls_result-chngind    = ls_cdpos-chngind.
    ls_result-value_new   = ls_cdpos-value_new.
    ls_result-value_old   = ls_cdpos-value_old.

        CASE ls_cdpos-chngind.
      WHEN 'I'.
        ls_result-chngtxt = 'Insert'.
      WHEN 'U'.
        ls_result-chngtxt = 'Update'.
      WHEN 'D'.
        ls_result-chngtxt = 'Delete'.
      WHEN 'J'.
        ls_result-chngtxt = 'Insert'.
      WHEN OTHERS.
        ls_result-chngtxt = ls_cdpos-chngind.
    ENDCASE.

    ls_result-tzone = sy-zonlo.

        APPEND ls_result TO lt_result.

  ENDLOOP.

ENDLOOP.

copy_data_to_ref(
  EXPORTING
    is_data = lt_result
  CHANGING
    cr_data = er_data ).


************** End of Code by Kanishk Arora ***************


  ENDCASE.

ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~get_expanded_entity.
**TRY.
*CALL METHOD SUPER->/IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_EXPANDED_ENTITY
**  EXPORTING
**    iv_entity_name           =
**    iv_entity_set_name       =
**    iv_source_name           =
**    it_key_tab               =
**    it_navigation_path       =
**    io_expand                =
**    io_tech_request_context  =
**  IMPORTING
**    er_entity                =
**    es_response_context      =
**    et_expanded_clauses      =
**    et_expanded_tech_clauses =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.

    DATA: BEGIN OF ls_deep.
            INCLUDE TYPE zcl_zz_arc_rec_manager_mpc=>ts_zcomprolehdr.
    DATA to_items1 TYPE zcl_zz_arc_rec_manager_mpc=>tt_zcomproleitem.
    DATA: END OF ls_deep.

    DATA lt_data TYPE TABLE OF zcomp_role_hdr.

    CASE iv_entity_set_name.
      WHEN 'ZCompRoleHdrSet'.
        IF it_key_tab IS NOT INITIAL.
          DATA(ls_agr_name) = CONV agr_name( it_key_tab[ name = 'AgrName' ]-value ).
          SELECT SINGLE * FROM zcomp_role_hdr INTO @DATA(ls_hdr)
            WHERE agr_name = @ls_agr_name.
          IF sy-subrc EQ 0.
*            DATA(ls_child_agr) = CONV child_agr( it_key_tab[ name = 'ChildAgr' ]-value ).
            SELECT * FROM zcomp_role_hdr INTO TABLE @DATA(lt_item)
              WHERE agr_name = @ls_agr_name.
*               AND child_agr = @ls_child_agr.
          ENDIF.
          ls_deep = CORRESPONDING #( ls_hdr ).
          ls_deep-to_items1 = CORRESPONDING #( lt_item ).

*          DATA(ls_child_agr) = CONV child_agr( it_key_tab[ name = 'ChildAgr' ]-value ).
          copy_data_to_ref(
            EXPORTING
              is_data = ls_deep
            CHANGING
              cr_data = er_entity
          ).
        ENDIF.
    ENDCASE.

  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~get_expanded_entityset.
**TRY.
*CALL METHOD SUPER->/IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_EXPANDED_ENTITYSET
**  EXPORTING
**    iv_entity_name           =
**    iv_entity_set_name       =
**    iv_source_name           =
**    it_filter_select_options =
**    it_order                 =
**    is_paging                =
**    it_navigation_path       =
**    it_key_tab               =
**    iv_filter_string         =
**    iv_search_string         =
**    io_expand                =
**    io_tech_request_context  =
**  IMPORTING
**    er_entityset             =
**    et_expanded_clauses      =
**    et_expanded_tech_clauses =
**    es_response_context      =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.

***    "------------------------------------------------------------
***    " Purpose:
***    "   Return Header entity set with items when $expand requested.
***    "   Source table: ZCOMP_ROLE_HDR (one row per CHILD_AGR)
***    "------------------------------------------------------------
***    DATA: BEGIN OF ts_deep_entity.
***            INCLUDE TYPE zcl_zz_arc_rec_manager_mpc_ext=>ts_zcomprolehdr.
***    DATA:   agr_item TYPE zcl_zz_arc_rec_manager_mpc_ext=>tt_zcomproleitem,
***          END OF ts_deep_entity.
***
***    DATA: lt_deep_entity LIKE TABLE OF ts_deep_entity,
***          ls_deep_entity LIKE LINE OF lt_deep_entity.
***
***    DATA: lv_setname TYPE string.
***    lv_setname = iv_entity_set_name.
***
***    "Only implement for your header entity set name
***    ">>> CHANGE 'ZCompRoleHdrSet' to your actual header entity set if different
***    IF lv_setname <> 'ZCompRoleHdrSet'.
***      super->/iwbep/if_mgw_appl_srv_runtime~get_expanded_entityset(
***        EXPORTING
***          iv_entity_name           = iv_entity_name
***          iv_entity_set_name       = iv_entity_set_name
***          iv_source_name           = iv_source_name
***          it_filter_select_options = it_filter_select_options
***          is_paging                = is_paging
***          it_key_tab               = it_key_tab
***          it_navigation_path       = it_navigation_path
***          it_order                 = it_order
***          iv_filter_string         = iv_filter_string
***          iv_search_string         = iv_search_string
***          io_tech_request_context  = io_tech_request_context
***        IMPORTING
***          er_entityset             = er_entityset
***          et_expanded_tech_clauses = et_expanded_tech_clauses ).
***      RETURN.
***    ENDIF.
***
***    "Check if client requested $expand
***    DATA(lo_expand) = io_tech_request_context->get_expand( ).
***    DATA(lv_expand_requested) = xsdbool( lo_expand IS NOT INITIAL ).
***
***    "------------------------------------------------------------
***    " Read filter AgrName if provided: $filter=AgrName eq '...'
***    " (Basic EQ handling only)
***    "------------------------------------------------------------
***    DATA lv_agr_name TYPE zcomp_role_hdr-agr_name.
***
***    READ TABLE it_filter_select_options ASSIGNING FIELD-SYMBOL(<f>)
***      WITH KEY property = 'AgrName'.  ">>> CHANGE if your property is AGR_NAME
***    IF sy-subrc = 0.
***      READ TABLE <f>-select_options ASSIGNING FIELD-SYMBOL(<so>) INDEX 1.
***      IF sy-subrc = 0 AND <so>-sign = 'I' AND <so>-option = 'EQ'.
***        lv_agr_name = <so>-low.
***      ENDIF.
***    ENDIF.
***
***    "------------------------------------------------------------
***    " Select DB rows
***    "------------------------------------------------------------
***    DATA lt_db TYPE TABLE OF zcomp_role_hdr.
***
***    IF lv_agr_name IS INITIAL.
***      SELECT * FROM zcomp_role_hdr INTO TABLE @lt_db.
***    ELSE.
***      SELECT * FROM zcomp_role_hdr INTO TABLE @lt_db
***        WHERE agr_name = @lv_agr_name.
***    ENDIF.
***
***    "Nothing found -> return empty set
***    IF lt_db IS INITIAL.
***      "Return empty deep set (or header set)
***      DATA: lt_empty TYPE STANDARD TABLE OF string.
***      copy_data_to_ref( EXPORTING is_data = lt_empty CHANGING cr_data = er_entityset ).
***      RETURN.
***    ENDIF.
***
***    "------------------------------------------------------------
***    " Build DEEP header table (Header + to_Items)
***    " IMPORTANT: Use your generated deep type name here.
***    " In MPC class, it is often TS_<Header>_DEEP and TT_<Header>_DEEP
***    "------------------------------------------------------------
***    "Sort to group by AGR_NAME, and to pick "latest" header fields
***    SORT lt_db BY agr_name changed_at created_at.
***
***    "Get distinct AGR_NAME values
***    DATA: lt_keys TYPE SORTED TABLE OF zcomp_role_hdr-agr_name WITH UNIQUE KEY table_line.
***    LOOP AT lt_db ASSIGNING FIELD-SYMBOL(<fs_item>).
***      INSERT <fs_item>-agr_name INTO TABLE lt_keys.
***    ENDLOOP.
***
***    LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<fs_header>).
***      CLEAR ls_deep_entity.
***
***      "Pick a representative row (last one = latest because of sort)
***      DATA(<fs_header>) = VALUE zcomp_role_hdr( ).
***      LOOP AT lt_db INTO <fs_header> WHERE agr_name = <fs_header>.
***        "intentionally empty; <fs_header> ends as last row in group
***      ENDLOOP.
***
***      "--------------------------------------------------------
***      " Map HEADER fields (adjust component names if needed)
***      "--------------------------------------------------------
***      ls_deep_entity-agr_name          = <fs_header>-agr_name.
***      ls_deep_entity-agr_name_descr     = <fs_header>-agr_name_descr.
***      ls_deep_entity-wf_approval_status = <fs_header>-wf_approval_status.
***      ls_deep_entity-approver         = <fs_header>-approver.
***      ls_deep_entity-reject_reason     = <fs_header>-reject_reason.
***      ls_deep_entity-approved_at       = <fs_header>-approved_at.
***      ls_deep_entity-rejected_at       = <fs_header>-rejected_at.
***      ls_deep_entity-created_at        = <fs_header>-created_at.
***      ls_deep_entity-changed_at        = <fs_header>-changed_at.
***
***      "--------------------------------------------------------
***      " Attach ITEMS (rows from DB)
***      " Navigation component name is usually: TO_ITEMS
***      "--------------------------------------------------------
***      LOOP AT lt_db ASSIGNING <fs_item> WHERE agr_name = <fs_header>.
***        APPEND VALUE zcl_zz_arc_rec_manager_mpc=>ts_zcomproleitem(
***          agr_name           = <fs_item>-agr_name
***          child_agr          = <fs_item>-child_agr
***          reason_child_agr   = <fs_item>-reason_child_agr
***          agr_name_descr     = <fs_item>-agr_name_descr
***          child_agr_descr    = <fs_item>-child_agr_descr
***          wf_approval_status = <fs_item>-wf_approval_status
***          approver           = <fs_item>-approver
***          reject_reason      = <fs_item>-reject_reason
***          approved_at        = <fs_item>-approved_at
***          rejected_at        = <fs_item>-rejected_at
***          created_at         = <fs_item>-created_at
***          changed_at         = <fs_item>-changed_at
***        ) TO ls_deep_entity-agr_item.
***      ENDLOOP.
***
***      APPEND ls_deep_entity TO lt_deep_entity.
***    ENDLOOP.
***
***
******SELECT * from zcomp_role_hdr INTO CORRESPONDING FIELDS OF TABLE lt_deep_entity.
***    "------------------------------------------------------------
***    " Return deep entity set (headers with expanded items)
***    "------------------------------------------------------------
***    copy_data_to_ref( EXPORTING is_data = lt_deep_entity CHANGING cr_data = er_entityset ).


    "Deep type: Header + expanded items (nav prop = to_Items)
*    DATA: it_header TYPE TABLE OF zcomp_role_hdr,
*          it_item   TYPE TABLE OF zcomp_role_hdr.
    """"""
    DATA: BEGIN OF ls_deep.
            INCLUDE TYPE zcl_zz_arc_rec_manager_mpc=>ts_zcomprolehdr.
    DATA to_items1 TYPE zcl_zz_arc_rec_manager_mpc=>tt_zcomproleitem.
    DATA: END OF ls_deep.

    DATA: lt_deep   LIKE TABLE OF ls_deep.

*    DATA lt_data TYPE TABLE OF zcomp_role_hdr.

    CASE iv_entity_set_name.
      WHEN 'ZCompRoleHdrSet'.
        IF it_key_tab IS NOT INITIAL.
        ELSE.
          SELECT * FROM zcomp_role_hdr INTO TABLE @DATA(lt_hdr).
          IF sy-subrc EQ 0.
            SELECT * FROM zcomp_role_hdr INTO TABLE @DATA(lt_item)
              FOR ALL ENTRIES IN @lt_hdr
             WHERE agr_name = @lt_hdr-agr_name.
            LOOP AT lt_hdr ASSIGNING FIELD-SYMBOL(<fs_hdr>).
              SELECT * FROM @lt_item AS lt_item_alias
                WHERE agr_name = @<fs_hdr>-agr_name
                INTO TABLE @DATA(lt_item_sub).
              APPEND INITIAL LINE TO lt_deep ASSIGNING FIELD-SYMBOL(<fs_deep>).
              <fs_deep>-agr_name = <fs_hdr>-agr_name.
              <fs_deep>-child_agr = <fs_hdr>-child_agr.
              <fs_deep>-to_items1 = lt_item_sub.
              CLEAR: <fs_hdr>-agr_name.
            ENDLOOP.

            SORT lt_deep BY agr_name.
            DELETE ADJACENT DUPLICATES FROM lt_deep COMPARING agr_name.

            copy_data_to_ref(
              EXPORTING
                is_data = lt_deep
              CHANGING
                cr_data = er_entityset
            ).
            APPEND 'TO_ITEMS1' TO et_expanded_tech_clauses.
          ENDIF.
        ENDIF.



*          ls_deep = CORRESPONDING #( ls_hdr ).
*          ls_deep-to_items1 = CORRESPONDING #( lt_item ).

*          DATA(ls_child_agr) = CONV child_agr( it_key_tab[ name = 'ChildAgr' ]-value ).


    ENDCASE.


  ENDMETHOD.


  METHOD comprolesinglero_get_entityset.
**TRY.
*CALL METHOD SUPER->COMPROLESINGLERO_GET_ENTITYSET
*  EXPORTING
*    IV_ENTITY_NAME           =
*    IV_ENTITY_SET_NAME       =
*    IV_SOURCE_NAME           =
*    IT_FILTER_SELECT_OPTIONS =
*    IS_PAGING                =
*    IT_KEY_TAB               =
*    IT_NAVIGATION_PATH       =
*    IT_ORDER                 =
*    IV_FILTER_STRING         =
*    IV_SEARCH_STRING         =
**    io_tech_request_context  =
**  IMPORTING
**    et_entityset             =
**    es_response_context      =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.

    SELECT * FROM agr_agrs INTO CORRESPONDING FIELDS OF TABLE et_entityset.
  ENDMETHOD.


  METHOD downloadroles_lo_get_entityset.

    DATA: lv_osql_where TYPE string,
          lv_top        TYPE i,
          lv_skip       TYPE i.

    DATA(lo_mc) = me->mo_context->get_message_container( ).

    SELECT * FROM zrecman_admin INTO TABLE @DATA(lt_recman_admin). "#CI_NOWHERE

    READ TABLE lt_recman_admin ASSIGNING FIELD-SYMBOL(<fs_recman_admin>) WITH KEY admin = sy-uname.
    IF sy-subrc IS NOT INITIAL.
*      MESSAGE e005(zz_arc_recman).
      lo_mc->add_message_text_only( iv_msg_type = 'E' iv_msg_text = 'You are not authorized to execute this tcode' ).
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_mc.

      EXIT.
    ENDIF.

    " 1. GET DYNAMIC FILTERS (Handles User, Role, System, Time, and Client)
    lv_osql_where = io_tech_request_context->get_osql_where_clause( ).

    " 2. FETCH DATA FROM DATABASE
    IF lv_osql_where IS NOT INITIAL.
      SELECT * FROM zrecman_dl_logs
               INTO CORRESPONDING FIELDS OF TABLE @et_entityset
               WHERE (lv_osql_where).
    ELSE.
      SELECT * FROM zrecman_dl_logs
               INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    ENDIF.

    " 3. APPLY SORTING ($orderby) USING THE STANDARD IMPORTING PARAMETER
    IF it_order IS NOT INITIAL AND et_entityset IS NOT INITIAL.
      /iwbep/cl_mgw_data_util=>orderby(
        EXPORTING
          it_order = it_order
        CHANGING
          ct_data  = et_entityset ).
    ENDIF.

    " 4. APPLY PAGING (After sorting to ensure pages load in correct order)
    lv_top  = io_tech_request_context->get_top( ).
    lv_skip = io_tech_request_context->get_skip( ).

    IF lv_skip IS NOT INITIAL.
      DELETE et_entityset TO lv_skip.
    ENDIF.

    IF lv_top IS NOT INITIAL.
      DELETE et_entityset FROM ( lv_top + 1 ).
    ENDIF.

    " 5. INLINE COUNT (For UI table pagination to know total records)
    IF io_tech_request_context->has_inlinecount( ) = abap_true.
      es_response_context-inlinecount = lines( et_entityset ).
    ENDIF.

  ENDMETHOD.


  METHOD kpiset_get_entityset.

    TYPES: BEGIN OF ty_data,
             created_at         TYPE zcomp_role_hdr-created_at,
             wf_approval_status TYPE zcomp_role_hdr-wf_approval_status,
           END OF ty_data.

    TYPES: BEGIN OF ty_kpi,
             period       TYPE char6,
             total_count  TYPE i,
             approved_cnt TYPE i,
             pending_cnt  TYPE i,
             rejected_cnt TYPE i,
           END OF ty_kpi.

    DATA: lt_data TYPE STANDARD TABLE OF ty_data,
          lt_kpi  TYPE HASHED TABLE OF ty_kpi WITH UNIQUE KEY period,
          ls_kpi  TYPE ty_kpi.

    DATA: lv_year    TYPE char4,
          lv_month   TYPE char2,
          lv_period  TYPE char6,
          lv_key     TYPE char6,
          lv_pattern TYPE char20.

* Read $filter
    DATA: lt_filter TYPE /iwbep/t_mgw_select_option,
          ls_filter TYPE /iwbep/s_mgw_select_option,
          ls_sel    TYPE /iwbep/s_cod_select_option.

    lt_filter = io_tech_request_context->get_filter( )->get_filter_select_options( ).

    LOOP AT lt_filter INTO ls_filter.

      READ TABLE ls_filter-select_options INTO ls_sel INDEX 1.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      CASE ls_filter-property.

        WHEN 'Year' OR 'YEAR'.
          lv_year = ls_sel-low.

        WHEN 'Month' OR 'MONTH'.
          lv_month = ls_sel-low.

      ENDCASE.

    ENDLOOP.

* Validate
    IF lv_year IS INITIAL.
      RETURN.
    ENDIF.

* Build pattern
    IF lv_month IS NOT INITIAL.
      CONCATENATE lv_year lv_month '%' INTO lv_pattern.
    ELSE.
      CONCATENATE lv_year '%' INTO lv_pattern.
    ENDIF.

* Fetch data
    SELECT created_at, wf_approval_status
      FROM zcomp_role_hdr
      INTO TABLE @lt_data
      WHERE created_at LIKE @lv_pattern.

* KPI Calculation
    LOOP AT lt_data INTO DATA(ls_data).

      IF lv_month IS NOT INITIAL.
        lv_key = ls_data-created_at+0(6).
      ELSE.
        lv_key = ls_data-created_at+0(4).
      ENDIF.

      READ TABLE lt_kpi INTO ls_kpi WITH KEY period = lv_key.

      IF sy-subrc <> 0.
        CLEAR ls_kpi.
        ls_kpi-period = lv_key.
        INSERT ls_kpi INTO TABLE lt_kpi.
        READ TABLE lt_kpi INTO ls_kpi WITH KEY period = lv_key.
      ENDIF.

      ls_kpi-total_count = ls_kpi-total_count + 1.

      DATA lv_status TYPE string.
      lv_status = ls_data-wf_approval_status.
      TRANSLATE lv_status TO UPPER CASE.

      CASE lv_status.
        WHEN 'APPROVED'.
          ls_kpi-approved_cnt = ls_kpi-approved_cnt + 1.
        WHEN 'PENDING'.
          ls_kpi-pending_cnt = ls_kpi-pending_cnt + 1.
        WHEN 'REJECTED'.
          ls_kpi-rejected_cnt = ls_kpi-rejected_cnt + 1.
      ENDCASE.

      MODIFY TABLE lt_kpi FROM ls_kpi.

    ENDLOOP.

* Output
    LOOP AT lt_kpi INTO ls_kpi.

      APPEND VALUE #(
        period        = ls_kpi-period
        year          = lv_year
        month         = lv_month
        totalcount    = ls_kpi-total_count
        approvedcount = ls_kpi-approved_cnt
        pendingcount  = ls_kpi-pending_cnt
        rejectedcount = ls_kpi-rejected_cnt
      ) TO et_entityset.
    ENDLOOP.

  ENDMETHOD.


  method OWNERGROUPAPPROV_GET_ENTITYSET.
**TRY.
*CALL METHOD SUPER->OWNERGROUPAPPROV_GET_ENTITYSET
*  EXPORTING
*    IV_ENTITY_NAME           =
*    IV_ENTITY_SET_NAME       =
*    IV_SOURCE_NAME           =
*    IT_FILTER_SELECT_OPTIONS =
*    IS_PAGING                =
*    IT_KEY_TAB               =
*    IT_NAVIGATION_PATH       =
*    IT_ORDER                 =
*    IV_FILTER_STRING         =
*    IV_SEARCH_STRING         =
**    io_tech_request_context  =
**  IMPORTING
**    et_entityset             =
**    es_response_context      =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.

      DATA:
    lt_req TYPE TABLE OF zcomp_owngrp_req,
    ls_req TYPE zcomp_owngrp_req.

  SELECT *
    FROM zcomp_owngrp_req
    INTO TABLE lt_req
    WHERE final_status = 'PENDING'.
*
*  LOOP AT lt_req INTO ls_req.
*
*    " User already approved as old approver
*    IF ls_req-old_approver = sy-uname
*       AND ls_req-old_approver_status = 'APPROVED'.
*      CONTINUE.
*    ENDIF.
*
*    " User already approved as new approver
*    IF ls_req-new_approver = sy-uname
*       AND ls_req-new_approver_status = 'APPROVED'.
*      CONTINUE.
*    ENDIF.
*
*    " User is involved
*    IF ls_req-old_approver = sy-uname
*       OR ls_req-new_approver = sy-uname.
*
*      APPEND CORRESPONDING #( ls_req ) TO et_entityset.
*
*    ENDIF.
*
*  ENDLOOP.

DATA:
  lv_old_auth TYPE abap_bool,
  lv_new_auth TYPE abap_bool.

LOOP AT lt_req INTO ls_req.

  lv_old_auth =
    zcl_arc_owngrp_service=>is_user_in_owner_group(
      iv_user        = sy-uname
      iv_owner_group = ls_req-old_owner_group
      iv_escalated   = xsdbool(
                         ls_req-escalation_sent = 'X' ) ).

  lv_new_auth =
    zcl_arc_owngrp_service=>is_user_in_owner_group(
      iv_user        = sy-uname
      iv_owner_group = ls_req-new_owner_group
      iv_escalated   = xsdbool(
                         ls_req-escalation_sent = 'X' ) ).

  IF ( lv_old_auth = abap_true
       AND ls_req-old_approver_status = 'PENDING' )

   OR

     ( lv_new_auth = abap_true
       AND ls_req-new_approver_status = 'PENDING' ).

    APPEND CORRESPONDING #( ls_req )
      TO et_entityset.

  ENDIF.

ENDLOOP.


  endmethod.


  METHOD ownergroup_sh_se_get_entityset.
    DATA: lt_dd07v TYPE STANDARD TABLE OF dd07v.

    " 1. Fetch the Fixed Values for the ZZ_OWNER_GROUP domain
    CALL FUNCTION 'DD_DOMVALUES_GET'
      EXPORTING
        domname        = 'ZZ_OWNER_GROUP'
        text           = abap_true
        langu          = sy-langu
      TABLES
        dd07v_tab      = lt_dd07v
      EXCEPTIONS
        wrong_textflag = 1
        OTHERS         = 2.

    IF sy-subrc = 0.
      " 2. Map the domain values to your OData EntitySet
      LOOP AT lt_dd07v INTO DATA(ls_dd07v).
        APPEND INITIAL LINE TO et_entityset ASSIGNING FIELD-SYMBOL(<ls_entity>).

        <ls_entity>-ownergroup = ls_dd07v-domvalue_l.
        <ls_entity>-description = ls_dd07v-ddtext.

      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD pendingapprovals_get_entityset.
***TRY.
**CALL METHOD SUPER->PENDINGAPPROVALS_GET_ENTITYSET
**  EXPORTING
**    IV_ENTITY_NAME           =
**    IV_ENTITY_SET_NAME       =
**    IV_SOURCE_NAME           =
**    IT_FILTER_SELECT_OPTIONS =
**    IS_PAGING                =
**    IT_KEY_TAB               =
**    IT_NAVIGATION_PATH       =
**    IT_ORDER                 =
**    IV_FILTER_STRING         =
**    IV_SEARCH_STRING         =
***    io_tech_request_context  =
***  IMPORTING
***    et_entityset             =
***    es_response_context      =
**    .
***  CATCH /iwbep/cx_mgw_busi_exception.
***  CATCH /iwbep/cx_mgw_tech_exception.
***ENDTRY.
*
*
*    SELECT *
*      FROM zcomp_role_hdr  INTO CORRESPONDING FIELDS OF TABLE et_entityset
**      WHERE wf_approval_status = 'PENDING'.
*      WHERE (iv_filter_string).
*   "ORDER BY created_at DESCENDING, agr_name DESCENDING.

*********Start of Code by Kanishk Arora********************************

    DATA:
      lt_roles_auth      TYPE TABLE OF zcomp_role_hdr,
      ls_role_auth       TYPE zcomp_role_hdr,
      lv_role_authorized TYPE abap_bool,
      lv_role_escalated  TYPE c LENGTH 1.

    SELECT *
      FROM zcomp_role_hdr
      INTO TABLE lt_roles_auth
      WHERE (iv_filter_string).



    LOOP AT lt_roles_auth INTO ls_role_auth.


      CLEAR:
        lv_role_authorized,
        lv_role_escalated.

      SELECT SINGLE escalation_sent
      FROM zrecman_reminder
      INTO @lv_role_escalated
      WHERE agr_name  = @ls_role_auth-agr_name
        AND child_agr = @ls_role_auth-child_agr.

      lv_role_authorized =
  zcl_arc_owngrp_service=>is_user_in_owner_group(
    iv_user        = sy-uname
    iv_owner_group = ls_role_auth-owner_group
    iv_escalated   = xsdbool(
                       lv_role_escalated = 'X' ) ).

      IF lv_role_authorized = abap_true.

        APPEND CORRESPONDING #( ls_role_auth )
          TO et_entityset.

      ENDIF.

    ENDLOOP.

*********End of Code by Kanishk Arora**********************************


  ENDMETHOD.


  METHOD roleslogsset_get_entityset.

    SELECT * FROM zrecman_logs
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset
      ORDER BY created_at DESCENDING, agr_name DESCENDING.

  ENDMETHOD.


METHOD save_zcomp_role_hdr.

  DATA: lv_ts  TYPE timestamp,
        lv_d   TYPE d,
        lv_t   TYPE t,
        lv_now TYPE char32,
        lt_db  TYPE TABLE OF zcomp_role_hdr.

********* Start of Code by Kanishk Arora ***************

  DATA: ls_og_trail     TYPE zcomp_og_trail,
        lv_uuid         TYPE sysuuid_x16,
        lv_ts_audit     TYPE timestampl,
        lv_old_ownergrp TYPE zz_owner_group.


********* End of Code by Kanishk Arora ******************

  DATA(lo_mc) = me->mo_context->get_message_container( ).

  GET TIME STAMP FIELD lv_ts.
  CONVERT TIME STAMP lv_ts TIME ZONE 'UTC' INTO DATE lv_d TIME lv_t.
  lv_now = |{ lv_d }{ lv_t }|. "YYYYMMDDHHMMSS in CHAR32 field

*-> Lock Object
  CALL FUNCTION 'ENQUEUE_EZAGR_AGRS'
    EXPORTING
      mandt          = sy-mandt
      agr_name       = is_hdr-agr_name
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.

  IF sy-subrc <> 0.
    CASE sy-subrc.
*-> Data record is currently locked by another session
      WHEN 1.
        DATA(lo_msg_cont) = mo_context->get_message_container( ).
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_RECMAN'
          iv_msg_number = '008' ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.

*-> System failure while trying to lock role
      WHEN 2.
        lo_msg_cont = mo_context->get_message_container( ).
        lo_msg_cont->add_message(
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZZ_ARC_RECMAN'
          iv_msg_number = '011' ).

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg_cont.

      WHEN OTHERS.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception.
    ENDCASE.
  ENDIF.

  IF iv_create_flag = 'X'.  " Create New Composite role with single roles
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<i>).
      APPEND VALUE zcomp_role_hdr(
        agr_name           = is_hdr-agr_name
        child_agr          = <i>-child_agr
        owner_group        = is_hdr-owner_group
        reason_child_agr   = <i>-reason_child_agr
        agr_name_descr     = is_hdr-agr_name_descr
        child_agr_descr    = <i>-child_agr_descr
*        req_user           = <i>-req_user
        req_user           = sy-uname
        wf_approval_status = COND #( WHEN is_hdr-wf_approval_status IS INITIAL
                                     THEN 'PENDING'
                                     ELSE 'PENDING' )
        approver           = is_hdr-approver
        reject_reason      = is_hdr-reject_reason
        approved_at        = is_hdr-approved_at
        rejected_at        = is_hdr-rejected_at
        created_at         = COND #( WHEN is_hdr-changed_at IS INITIAL
                                     THEN lv_now
                                     ELSE lv_now )
      ) TO lt_db.
    ENDLOOP.

    MODIFY zcomp_role_hdr FROM TABLE lt_db.

********* Start of Code by Kanishk Arora ***************

    GET TIME STAMP FIELD lv_ts_audit.

    CALL FUNCTION 'SYSTEM_UUID_CREATE'
      IMPORTING
        uuid = lv_uuid.

    CLEAR ls_og_trail.

    ls_og_trail-mandt         = sy-mandt.
    ls_og_trail-audit_id      = lv_uuid.
    ls_og_trail-role_name     = is_hdr-agr_name.
    ls_og_trail-old_owner_grp = ''.
    ls_og_trail-new_owner_grp = is_hdr-owner_group.
    ls_og_trail-changed_by    = sy-uname.
    ls_og_trail-changed_at    = lv_ts_audit.
    ls_og_trail-action_type   = 'CREATE'.

    INSERT zcomp_og_trail FROM ls_og_trail.

********* End of Code by Kanishk Arora ******************

    COMMIT WORK.
    IF sy-subrc <> 0.
      lo_mc->add_message_text_only( iv_msg_type = 'E' iv_msg_text = 'Failed to save ZCOMP_ROLE_HDR.' ).
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_mc.
    ENDIF.
  ELSE.    " Update Existing Composite role with single roles

********* Start of Code by Kanishk Arora ***************

    SELECT SINGLE owner_group
    FROM zcomp_role_hdr
    INTO lv_old_ownergrp
    WHERE agr_name = is_hdr-agr_name.

    DATA lv_ownergrp_changed TYPE abap_bool.

    CLEAR lv_ownergrp_changed.

    IF lv_old_ownergrp <> is_hdr-owner_group.
      lv_ownergrp_changed = abap_true.

      zcl_arc_owngrp_service=>create_or_update_request(
        iv_role_name       = is_hdr-agr_name
        iv_old_owner_group = lv_old_ownergrp
        iv_new_owner_group = is_hdr-owner_group
        iv_requested_by    = sy-uname ).
    ENDIF.

********* End of Code by Kanishk Arora ******************

    LOOP AT it_items ASSIGNING <i>.
      APPEND VALUE zcomp_role_hdr(
        agr_name           = is_hdr-agr_name
        child_agr          = <i>-child_agr
*        owner_group        = is_hdr-owner_group

********* Start of Code by Kanishk Arora ***************

      owner_group = COND #(
                    WHEN lv_ownergrp_changed = abap_true
                    THEN lv_old_ownergrp
                    ELSE is_hdr-owner_group )

********* End of Code by Kanishk Arora ******************
        reason_child_agr   = <i>-reason_child_agr
        agr_name_descr     = is_hdr-agr_name_descr
        child_agr_descr    = <i>-child_agr_descr
        wf_approval_status = COND #( WHEN is_hdr-wf_approval_status IS INITIAL
                                     THEN 'PENDING'
                                     ELSE is_hdr-wf_approval_status )
        approver           = is_hdr-approver
        reject_reason      = is_hdr-reject_reason
        approved_at        = is_hdr-approved_at
        rejected_at        = is_hdr-rejected_at
        changed_at         = COND #( WHEN is_hdr-changed_at IS INITIAL
                                     THEN lv_now
                                     ELSE lv_now )
        created_at         = is_hdr-created_at
      ) TO lt_db.
    ENDLOOP.

    MODIFY zcomp_role_hdr FROM TABLE lt_db.
    COMMIT WORK.


********* Start of Code by Kanishk Arora ***************

*IF lv_old_ownergrp <> is_hdr-owner_group.
*
*  GET TIME STAMP FIELD lv_ts_audit.
*
*  CALL FUNCTION 'SYSTEM_UUID_CREATE'
*    IMPORTING
*      uuid = lv_uuid.
*
*  CLEAR ls_og_trail.
*
*  ls_og_trail-mandt         = sy-mandt.
*  ls_og_trail-audit_id      = lv_uuid.
*  ls_og_trail-role_name     = is_hdr-agr_name.
*  ls_og_trail-old_owner_grp = lv_old_ownergrp.
*  ls_og_trail-new_owner_grp = is_hdr-owner_group.
*  ls_og_trail-changed_by    = sy-uname.
*  ls_og_trail-changed_at    = lv_ts_audit.
*  ls_og_trail-action_type   = 'CHANGE'.
*
*  INSERT zcomp_og_trail FROM ls_og_trail.
*
*ENDIF.

********* End of Code by Kanishk Arora ******************

    IF sy-subrc <> 0.
      lo_mc->add_message_text_only( iv_msg_type = 'E' iv_msg_text = 'Failed to save ZCOMP_ROLE_HDR.' ).
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_mc.
    ENDIF.

*->  Unlock the object
    CALL FUNCTION 'DEQUEUE_EZAGR_AGRS'
      EXPORTING
*       mode_agr_agrs = 'E'         " Lock mode for table AGR_AGRS
        mandt    = sy-mandt         " Enqueue argument 01
        agr_name = is_hdr-agr_name.    " Enqueue argument 02
  ENDIF.
ENDMETHOD.


  METHOD transportrolesse_get_entityset.
**TRY.
*CALL METHOD SUPER->TRANSPORTROLESSE_GET_ENTITYSET
*  EXPORTING
*    IV_ENTITY_NAME           =
*    IV_ENTITY_SET_NAME       =
*    IV_SOURCE_NAME           =
*    IT_FILTER_SELECT_OPTIONS =
*    IS_PAGING                =
*    IT_KEY_TAB               =
*    IT_NAVIGATION_PATH       =
*    IT_ORDER                 =
*    IV_FILTER_STRING         =
*    IV_SEARCH_STRING         =
**    io_tech_request_context  =
**  IMPORTING
**    et_entityset             =
**    es_response_context      =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.

 SELECT * FROM zrecman_logs_tr
  INTO CORRESPONDING FIELDS OF TABLE @et_entityset
  ORDER BY created_at DESCENDING, agr_name DESCENDING.

  ENDMETHOD.


METHOD zcomprolehdrset_create_entity.

  "------------------------------------------------------------
  " Create Composite Role + Save request into ZCOMP_ROLE_HDR
  " Service: ZZ_ARC_REC_MANAGER_SRV
  " EntitySet: ZCompRoleHdrSet
  "------------------------------------------------------------

  DATA: ls_hdr  TYPE zcl_zz_arc_rec_manager_mpc_ext=>ts_zcomprolehdr,
        lt_item TYPE zcl_zz_arc_rec_manager_mpc_ext=>tt_zcomproleitem,
        lt_ret1 TYPE bapiret2_t,
        lt_ret2 TYPE bapiret2_t.

  DATA(lo_mc) = me->mo_context->get_message_container( ).


  "1) Read payload into header structure
  io_data_provider->read_entry_data( IMPORTING es_data = ls_hdr ).

  "1.a) Fetch Role Description if empty
  IF ls_hdr-child_agr_descr IS INITIAL.
    SELECT SINGLE text FROM agr_texts INTO @DATA(lv_agr_texts)
      WHERE agr_name = @ls_hdr-child_agr
      AND spras = @sy-langu.
    IF sy-subrc EQ 0.
      ls_hdr-child_agr_descr = lv_agr_texts.
    ENDIF.
  ENDIF.

  "2) Basic validations
  IF ls_hdr-Agr_Name IS INITIAL.
    lo_mc->add_message_text_only( iv_msg_type = 'E' iv_msg_text = 'AGR_NAME is required.' ).
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING
        message_container = lo_mc.
  ENDIF.

  IF ls_hdr-agr_name_descr IS INITIAL.
    lo_mc->add_message_text_only( iv_msg_type = 'E' iv_msg_text = 'AGR_NAME_DESCR is required.' ).
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING
        message_container = lo_mc.
  ENDIF.

  "3) Create composite role if CreateFlag = X
  "   (Rename field below if your property name differs)
  IF ls_hdr-create_flag = abap_true.

    CALL FUNCTION 'PRGN_RFC_CREATE_AGR_MULTIPLE'
      EXPORTING
        activity_group      = ls_hdr-Agr_Name
        activity_group_text = ls_hdr-agr_name_descr
        collective_agr      = abap_true
      TABLES
        return              = lt_ret1
      EXCEPTIONS
        OTHERS              = 8.

    IF line_exists( lt_ret1[ type = 'E' ] )
    OR line_exists( lt_ret1[ type = 'A' ] )
    OR line_exists( lt_ret1[ type = 'X' ] ).
      ROLLBACK WORK.
      zcl_odata_msg=>raise_bapiret2( io_mc = lo_mc it_ret = lt_ret1 ).
    ENDIF.

  ENDIF.

  "4) Save to Z table
  "   Since CREATE_ENTITY has no items, we insert only header row (optional)
  "   If your DB requires CHILD_AGR, then either:
  "   - make CHILD_AGR mandatory in header entity, OR
  "   - use deep create instead.
  me->save_zcomp_role_hdr(
    is_hdr   = ls_hdr
    it_items = lt_item ).

  "5) Commit once
  COMMIT WORK AND WAIT.

  "6) Run external program AFTER commit
  SUBMIT z_arc_recman_reminder AND RETURN.

  "7) Return created entity
  er_entity = ls_hdr.

ENDMETHOD.


  METHOD zcomprolehdrset_get_entity.
**TRY.
*CALL METHOD SUPER->ZCOMPROLEHDRSET_GET_ENTITY
*  EXPORTING
*    IV_ENTITY_NAME          =
*    IV_ENTITY_SET_NAME      =
*    IV_SOURCE_NAME          =
*    IT_KEY_TAB              =
**    io_request_object       =
**    io_tech_request_context =
*    IT_NAVIGATION_PATH      =
**  IMPORTING
**    er_entity               =
**    es_response_context     =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.
    BREAK-POINT.

    IF it_key_tab IS NOT INITIAL.
      DATA(ls_agr_name) = CONV agr_name( it_key_tab[ name = 'AgrName' ]-value ).
      SELECT SINGLE * FROM zcomp_role_hdr INTO @DATA(ls_hdr)
        WHERE agr_name = @ls_agr_name.
      IF sy-subrc EQ 0.
        er_entity = CORRESPONDING #( ls_hdr ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD zcomprolehdrset_get_entityset.
**TRY.
*CALL METHOD SUPER->ZCOMPROLEHDRSET_GET_ENTITYSET
*  EXPORTING
*    IV_ENTITY_NAME           =
*    IV_ENTITY_SET_NAME       =
*    IV_SOURCE_NAME           =
*    IT_FILTER_SELECT_OPTIONS =
*    IS_PAGING                =
*    IT_KEY_TAB               =
*    IT_NAVIGATION_PATH       =
*    IT_ORDER                 =
*    IV_FILTER_STRING         =
*    IV_SEARCH_STRING         =
**    io_tech_request_context  =
**  IMPORTING
**    et_entityset             =
**    es_response_context      =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.
    DATA lt_data TYPE TABLE OF zcomp_role_hdr.

    IF it_key_tab IS NOT INITIAL.
      LOOP AT it_key_tab ASSIGNING FIELD-SYMBOL(<fs_key_tab>)
      WHERE name = 'AgrName'.
        APPEND INITIAL LINE TO lt_data ASSIGNING FIELD-SYMBOL(<fs_data>).
        <fs_data>-agr_name = <fs_key_tab>-value.
      ENDLOOP.
      IF lt_data IS NOT INITIAL.
        SELECT * FROM zcomp_role_hdr INTO CORRESPONDING FIELDS OF TABLE
          @et_entityset FOR ALL ENTRIES IN @lt_data
          WHERE agr_name = @lt_data-agr_name.
      ENDIF.
    ELSE.
      SELECT * FROM zcomp_role_hdr INTO CORRESPONDING FIELDS OF TABLE
        @et_entityset.
    ENDIF.

  ENDMETHOD.


  METHOD zcomproleitemset_get_entity.
**TRY.
*CALL METHOD SUPER->ZCOMPROLEITEMSET_GET_ENTITY
*  EXPORTING
*    IV_ENTITY_NAME          =
*    IV_ENTITY_SET_NAME      =
*    IV_SOURCE_NAME          =
*    IT_KEY_TAB              =
**    io_request_object       =
**    io_tech_request_context =
*    IT_NAVIGATION_PATH      =
**  IMPORTING
**    er_entity               =
**    es_response_context     =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.
BREAK-POINT.

    IF it_key_tab IS NOT INITIAL.
      DATA(ls_agr_name) = CONV agr_name( it_key_tab[ name = 'AgrName' ]-value ).
      DATA(ls_child_agr) = CONV child_agr( it_key_tab[ name = 'ChildAgr' ]-value ).
      SELECT SINGLE * FROM zcomp_role_hdr INTO @DATA(ls_item)
        WHERE agr_name = @ls_agr_name
        AND child_agr = @ls_child_agr.
      IF sy-subrc EQ 0.
        er_entity = CORRESPONDING #( ls_item ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD zcomproleitemset_get_entityset.
**TRY.
*CALL METHOD SUPER->ZCOMPROLEITEMSET_GET_ENTITYSET
*  EXPORTING
*    IV_ENTITY_NAME           =
*    IV_ENTITY_SET_NAME       =
*    IV_SOURCE_NAME           =
*    IT_FILTER_SELECT_OPTIONS =
*    IS_PAGING                =
*    IT_KEY_TAB               =
*    IT_NAVIGATION_PATH       =
*    IT_ORDER                 =
*    IV_FILTER_STRING         =
*    IV_SEARCH_STRING         =
**    io_tech_request_context  =
**  IMPORTING
**    et_entityset             =
**    es_response_context      =
*    .
**  CATCH /iwbep/cx_mgw_busi_exception.
**  CATCH /iwbep/cx_mgw_tech_exception.
**ENDTRY.
    DATA lt_data TYPE TABLE OF zcomp_role_hdr.

    IF it_key_tab IS NOT INITIAL.
      LOOP AT it_key_tab ASSIGNING FIELD-SYMBOL(<fs_key_tab>)
      WHERE name = 'AgrName'.
        APPEND INITIAL LINE TO lt_data ASSIGNING FIELD-SYMBOL(<fs_data>).
        <fs_data>-agr_name = <fs_key_tab>-value.
      ENDLOOP.
      LOOP AT it_key_tab ASSIGNING <fs_key_tab>
      WHERE name = 'ChildAgr'.
        APPEND INITIAL LINE TO lt_data ASSIGNING <fs_data>.
        <fs_data>-agr_name = <fs_key_tab>-value.
      ENDLOOP.

      IF lt_data IS NOT INITIAL.
        SELECT * FROM zcomp_role_hdr INTO CORRESPONDING FIELDS OF TABLE
          @et_entityset FOR ALL ENTRIES IN @lt_data
          WHERE agr_name = @lt_data-agr_name.
      ENDIF.
    ELSE.
      SELECT * FROM zcomp_role_hdr INTO CORRESPONDING FIELDS OF TABLE
        @et_entityset.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
