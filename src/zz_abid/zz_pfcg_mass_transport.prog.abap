REPORT zz_pfcg_mass_transport.

TABLES: agr_define.

TYPE-POOLS: icon.

CONSTANTS: gc_ty     TYPE menu_attr VALUE 'NO_TYPE',
           gc_no_rec TYPE menu_attr VALUE 'NO_REC'.

TYPES: BEGIN OF type_selct_role,
         role     TYPE agr_name,
         inh_role TYPE agr_name,
         text     TYPE agr_title,
         fl_typ   TYPE flag_type,
         fl_val   TYPE agr_att2,
       END OF type_selct_role,

       BEGIN OF type_rec_role,
         role     TYPE agr_name,
         inh_role TYPE agr_name,
         rqst     TYPE trkorr,
       END OF type_rec_role,

       BEGIN OF type_text,
         role TYPE agr_name,
         text TYPE agr_title,
       END OF type_text,

       BEGIN OF type_log_tab,
         role     TYPE agr_name,
         type     TYPE char01,
         sgl_role TYPE agr_name,
         inh_role TYPE agr_name,
         rqst     TYPE trkorr,
         error    TYPE menu_attr,
       END OF type_log_tab,

       BEGIN OF type_output,
         status    TYPE char80,                       "icon
         role      TYPE agr_name,
         role_type TYPE char80,                       "icon
         text      TYPE agr_title,
         sgl_role  TYPE agr_name,
         inh_role  TYPE par_agr,
         rqst      TYPE trkorr,
         error     TYPE menu_attr,
         err_text  TYPE bapi_msg,
       END OF type_output.

CONSTANTS: gc_pack_size TYPE sytabix VALUE 500.

DATA: gr_table TYPE REF TO cl_salv_table.

DATA: gt_sel_pack TYPE RANGE OF agr_name.

FIELD-SYMBOLS: <role_chk> LIKE LINE OF gt_sel_pack.

DATA: gt_sel_all    TYPE TABLE OF type_selct_role,
      gt_texts      TYPE TABLE OF type_text,
      gt_old_reqs   TYPE TABLE OF type_rec_role,
      gt_sgls_rec_o TYPE TABLE OF type_rec_role,
      gt_sgls_rec_n TYPE TABLE OF type_rec_role,
      gt_sgls_1_req TYPE TABLE OF type_rec_role,
      gt_cols_rec_o TYPE TABLE OF type_rec_role,
      gt_cols_rec_n TYPE TABLE OF type_rec_role,
      gt_cols_1_req TYPE TABLE OF type_rec_role,
      gt_validity   TYPE TABLE OF type_log_tab,
      gt_log_all    TYPE TABLE OF type_log_tab,
      gt_log_tmp    TYPE TABLE OF type_log_tab,
      gt_ret_dummy  TYPE TABLE OF bapiret2,
      gt_cid        TYPE TABLE OF tmw_adm,
      gt_output     TYPE TABLE OF type_output.

DATA: gs_rec_role TYPE type_rec_role,
      gs_validity TYPE type_log_tab,
      gs_output   TYPE type_output.

DATA: gd_err_text   TYPE char50,
      gd_variant    TYPE raldb_vari,
      gd_nr_sels    TYPE sytabix,
      gd_subrc      TYPE sysubrc,
      gd_msgv       TYPE symsgv,
      gd_role       TYPE agr_name,
      gd_icon_grey  TYPE char80,
      gd_icon_green TYPE char80,
      gd_icon_yello TYPE char80,
      gd_icon_red   TYPE char80,
      gd_icon_sgl   TYPE char80,
      gd_icon_col   TYPE char80,
      gd_request    TYPE trkorr,
      gd_req_tmp    TYPE trkorr.

DATA: gf_scc4_actv       TYPE char01 VALUE space,
      gf_all_or_no       TYPE char01 VALUE space,
      gf_coll_flag       TYPE char01,
      gf_tr_sgls_in_cols TYPE char01,
      gf_tr_profs        TYPE char01,
      gf_tr_pers_data    TYPE char01,
      gf_tr_us_asgm      TYPE char01,
      gf_sap_sys         TYPE char01 VALUE space,
      gf_csol_active     TYPE char01 VALUE space,
      gf_rfc_task        TYPE char01 VALUE space,
      gf_sap_only        TYPE char01,
      gf_error           TYPE char01,
      gf_cancel          TYPE char01.

FIELD-SYMBOLS: <role_sel> TYPE type_selct_role,
               <req>      TYPE type_rec_role,
               <rec>      TYPE type_rec_role,
               <log>      TYPE type_log_tab,
               <text>     TYPE type_text.

* Declaration of selection option
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-012.
SELECT-OPTIONS: agr_name FOR agr_define-agr_name.
SELECTION-SCREEN END OF BLOCK b1.

* Transport options
SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text71.

* Single roles in collective roles
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS comp_rol AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(75) text72 FOR FIELD comp_rol.
SELECTION-SCREEN END OF LINE.
* Generated profiles of single roles
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS profiles AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 4(75) text73 FOR FIELD profiles.
SELECTION-SCREEN END OF LINE.
* Personalization data
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS person AS CHECKBOX.
SELECTION-SCREEN COMMENT 4(75) text74 FOR FIELD person.
SELECTION-SCREEN END OF LINE.
* User assignments
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS users AS CHECKBOX.
SELECTION-SCREEN COMMENT 4(75) text75 FOR FIELD users.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b2.

* Test mode
SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE text78.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS testmode AS CHECKBOX DEFAULT 'X' MODIF ID tst.
SELECTION-SCREEN COMMENT 3(75) text79 FOR FIELD testmode MODIF ID tst.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b3.

* Evaluation of cross system object locks
SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE text76.

SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS csol_eva AS CHECKBOX MODIF ID csl.
SELECTION-SCREEN COMMENT 3(75) text77 FOR FIELD csol_eva MODIF ID csl.
SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b4.

* Macro for creating icons
DEFINE get_icon.
  CALL FUNCTION 'ICON_CREATE'
    EXPORTING
      name                  = &1
      info                  = &2
    IMPORTING
      result                = &3
    EXCEPTIONS
      icon_not_found        = 1
      outputfield_too_short = 2
      OTHERS                = 3.
  IF sy-subrc NE 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.
END-OF-DEFINITION.
* Icon creation

get_icon 'ICON_ACTIVITY_GROUP'          'Single role'(086)
          gd_icon_sgl.
get_icon 'ICON_COMPOSITE_ACTIVITYGROUP' 'Composite role'(085)
          gd_icon_col.

*---------------------------------------------------------------------*
*       CLASS lcl_handle_events DEFINITION
*---------------------------------------------------------------------*
CLASS lcl_handle_events DEFINITION.
  PUBLIC SECTION.
    METHODS: on_link_click FOR EVENT link_click OF cl_salv_events_table
      IMPORTING row column.

ENDCLASS.               "lcl_handle_events DEFINITION
DATA: gr_events TYPE REF TO lcl_handle_events.

*---------------------------------------------------------------------*
*       CLASS lcl_handle_events IMPLEMENTATION
*---------------------------------------------------------------------*
CLASS lcl_handle_events IMPLEMENTATION.

  METHOD on_link_click.
    PERFORM click_on_role USING row column.
  ENDMETHOD.                    "on_link_click

ENDCLASS.               "lcl_handle_events implementation.

*-----------------------------------------------------------------------
*                            INITIALIZATION
*-----------------------------------------------------------------------
INITIALIZATION.

* Cancellation of background jobs
  IF sy-batch IS NOT INITIAL.
    MESSAGE s098(s#) WITH sy-repid DISPLAY LIKE 'E'.
    LEAVE PROGRAM.
  ENDIF.

* Authorization check on S_TCODE due to possible start via SA38 or SE38
  IF sy-tcode NE 'PFCG'.
    CALL FUNCTION 'AUTHORITY_CHECK_TCODE'
      EXPORTING
        tcode  = 'PFCG'
      EXCEPTIONS
        ok     = 0
        not_ok = 1
        OTHERS = 2.
    IF sy-subrc NE 0.
      IF sy-msgid IS INITIAL.
        MESSAGE s077(s#) WITH 'PFCG' DISPLAY LIKE 'E'.
      ELSE.
        MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno DISPLAY LIKE 'E'
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
      LEAVE PROGRAM.
    ENDIF.
  ENDIF.

* Checking the client setting for client specific customizing objects
  CALL FUNCTION 'PRGN_CHK_CLIENT_CUST_SETTING'
    EXCEPTIONS
      no_transport_allowed    = 1
      no_solman_rfc_available = 2
      rfc_error               = 3
      automatic_recording     = 4
      OTHERS                  = 5.
  CASE sy-subrc.
    WHEN 1 OR 2 OR 3.
*     Exceptions 2 and 3 can occur in case of automatic recording only.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno DISPLAY LIKE 'E'
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      LEAVE PROGRAM.
    WHEN 4.
*     SCC4 setting active with automatic recording
      gf_scc4_actv = 'A'.
    WHEN 5.
*     SCC4 setting active but no automatic recording
      gf_scc4_actv = 'X'.
  ENDCASE.

* An arbitrary authorization of S_USER_AGR, ACTVT = 21 is additionally
* required.
  AUTHORITY-CHECK OBJECT 'S_USER_AGR'
           ID 'ACT_GROUP' DUMMY
           ID 'ACTVT' FIELD '21'.
  IF sy-subrc NE 0.
    gd_err_text = 'No authorization for role transport'(070).
    MESSAGE s240(s#) WITH gd_err_text DISPLAY LIKE 'E'.
    LEAVE PROGRAM.
  ENDIF.

* The default for profile data deviates between SAP and customer.
  CALL FUNCTION 'PRGN_CHECK_SYSTEM_TYPE'
    EXCEPTIONS
      sap_system = 1
      OTHERS     = 2.
  IF sy-subrc EQ 1.
    CLEAR profiles.
    gf_sap_sys = 'X'.
*   SAP internal: Checking customizing switch for recording SAP roles
*   only
    PERFORM cust_set_4_rec_sap_only IN PROGRAM saplprgn
                                    CHANGING gf_sap_only.
  ENDIF.

* Checking customizing settings for displaying transport options
  PERFORM chk_cust_settings IN PROGRAM saplprgn
                            CHANGING gf_tr_sgls_in_cols gf_tr_profs
                                     gf_tr_pers_data    gf_tr_us_asgm.

* Checking CSOL activity in order to show option for individual
* lock evalution per role
  CALL FUNCTION 'TMW_PRJL_CHECK_ACTIVATION'
    IMPORTING
      et_cid   = gt_cid
    EXCEPTIONS
      inactive = 1
      OTHERS   = 2.
  IF sy-subrc EQ 0.
    READ TABLE gt_cid WITH KEY cid        = 'CSL'
                               cid_active = 'X'
                      TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      gf_csol_active = 'X'.
    ENDIF.
  ENDIF.

  gd_variant = sy-slset.

  text71 = 'Optional components'(071).
  text72 = 'Single roles in composite roles'(072).
  text73 = 'Generated profiles of single roles'(073).
  text74 = 'Personalization data'(074).
  text75 = 'Direct user assignments'(075).
  text76 = 'Cross System Object Log'(076).
  text77 = 'Separate CSOL evalution for each role'(077).
  text78 = 'Test mode'(078).
  text79 = 'No record, status display only'(079).

*-----------------------------------------------------------------------
*                  AT SELECTION-SCREEN OUTPUT
*-----------------------------------------------------------------------
AT SELECTION-SCREEN OUTPUT.

* Checking the correct variant if exactly one certain role is selected
  IF gd_variant NE space.
    DESCRIBE TABLE agr_name LINES gd_nr_sels.
    IF gd_nr_sels EQ 1.
      READ TABLE agr_name ASSIGNING <role_chk> INDEX 1.
      IF <role_chk>-sign EQ 'I' AND <role_chk>-option EQ 'EQ'.
        CALL FUNCTION 'PRGN_GET_COLLECTIVE_AGR_FLAG'
          EXPORTING
            activity_group      = <role_chk>-low
          IMPORTING
            collective_agr_flag = gf_coll_flag
          EXCEPTIONS
            agr_does_not_exist  = 1
            flag_not_available  = 2
            OTHERS              = 3.
        IF sy-subrc EQ 0.
          IF gf_coll_flag EQ 'X'.
            gd_variant = 'SAP&COMP_AGR'.
          ELSE.
            gd_variant = 'SAP&SINGLE_AGR'.
            CLEAR gf_tr_sgls_in_cols.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
    IF gf_sap_sys EQ 'X' AND
     ( gd_variant EQ 'SAP&COMP_AGR' OR gd_variant EQ 'SAP&SINGLE_AGR' ).
      CLEAR profiles.
    ENDIF.
  ENDIF.

* Handle selection screen parameters
  LOOP AT SCREEN.
    CASE screen-group1.
      WHEN 'TST'.
        IF gf_scc4_actv NE space.
          screen-input = '1'.
        ELSE.
          CLEAR testmode.
          screen-invisible = '1'.
        ENDIF.
        MODIFY SCREEN.
        CONTINUE.
      WHEN 'CSL'.
        IF gf_csol_active EQ 'X'.
          screen-input = '1'.
        ELSE.
          CLEAR csol_eva.
          screen-invisible = '1'.
        ENDIF.
        MODIFY SCREEN.
        CONTINUE.
    ENDCASE.
    CASE screen-name.
      WHEN 'AGR_NAME-LOW'.
        IF gd_variant EQ 'SAP&COMP_AGR'   OR
           gd_variant EQ 'SAP&SINGLE_AGR'.
          screen-input = '0'.
          MODIFY SCREEN.
        ENDIF.
      WHEN '%_AGR_NAME_%_APP_%-TO_TEXT'   OR 'AGR_NAME-HIGH' OR
           '%_AGR_NAME_%_APP_%-VALU_PUSH'.
        IF gd_variant EQ 'SAP&COMP_AGR'   OR
           gd_variant EQ 'SAP&SINGLE_AGR'.
          screen-invisible = '1'.
          MODIFY SCREEN.
        ENDIF.
      WHEN 'COMP_ROL'.
        IF gf_tr_sgls_in_cols EQ 'X'.
          screen-input = '1'.
        ELSE.
          CLEAR comp_rol.
          screen-input = '0'.
        ENDIF.
        MODIFY SCREEN.
      WHEN 'PROFILES'.
        IF gf_tr_profs EQ 'X'.
          screen-input = '1'.
        ELSE.
          CLEAR profiles.
          screen-input = '0'.
        ENDIF.
        MODIFY SCREEN.
      WHEN 'PERSON'.
        IF gf_tr_pers_data EQ 'X'.
          screen-input = '1'.
        ELSE.
          CLEAR person.
          screen-input = '0'.
        ENDIF.
        MODIFY SCREEN.
      WHEN 'USERS'.
        IF gf_tr_us_asgm EQ 'X'.
          screen-input = '1'.
        ELSE.
          CLEAR users.
          screen-input = '0'.
        ENDIF.
        MODIFY SCREEN.
    ENDCASE.
  ENDLOOP.

*-----------------------------------------------------------------------
*                  AT SELECTION-SCREEN
*-----------------------------------------------------------------------
AT SELECTION-SCREEN.

  IF sy-ucomm NE '%001'.
*   Multiple selection was executed.
    IF agr_name-low IS INITIAL.
      IF agr_name-high IS INITIAL.
        MESSAGE e080(5@). " Choose at least one role
      ELSE.
*       'From' field must not be empty if 'To' field is filled.
        MESSAGE e014(5@).
      ENDIF.
    ENDIF.
  ENDIF.

*-----------------------------------------------------------------------
*                  AT SELECTION-SCREEN ON END OF <seltab>
*-----------------------------------------------------------------------
AT SELECTION-SCREEN ON END OF agr_name.

* Checking the role selections
  IF sy-ucomm NE 'NONE' AND sy-ucomm NE 'CANC'.
    LOOP AT agr_name.
      IF     agr_name-low  IS INITIAL AND
         NOT agr_name-high IS INITIAL.
*       'From' field must not be empty if 'To' field is filled.
        MESSAGE e014(5@).
      ENDIF.
    ENDLOOP.
  ENDIF.

*-----------------------------------------------------------------------
*           START-OF-SELECTION
*-----------------------------------------------------------------------
START-OF-SELECTION.

* I. Role selection (name, type and short text)

  PERFORM init_global_rec_tabs IN PROGRAM saplprgn.
  CLEAR: gt_sel_all, gt_texts, gt_validity,
         gt_sgls_rec_o, gt_cols_rec_o, gt_sgls_rec_n, gt_cols_rec_n.
  DO.
    CLEAR gt_sel_pack.
    DESCRIBE TABLE agr_name LINES gd_nr_sels.
    IF gd_nr_sels GT gc_pack_size.
      APPEND LINES OF agr_name FROM 1 TO gc_pack_size TO gt_sel_pack.
      DELETE agr_name FROM 1 TO gc_pack_size.
    ELSE.
      APPEND LINES OF agr_name TO gt_sel_pack.
      REFRESH agr_name.
    ENDIF.
    SELECT agr_define~agr_name agr_define~parent_agr agr_texts~text
           agr_flags~flag_type agr_flags~flag_value
           APPENDING TABLE gt_sel_all
           FROM agr_define                             "#EC CI_BUFFJOIN
           LEFT OUTER JOIN agr_texts
                           ON  agr_texts~agr_name = agr_define~agr_name
                           AND agr_texts~spras    = sy-langu
                           AND agr_texts~line     = 0
           LEFT OUTER JOIN agr_flags
                           ON  agr_flags~agr_name  = agr_define~agr_name
                           AND agr_flags~flag_type = 'COLL_AGR'
           WHERE agr_define~agr_name IN gt_sel_pack.
    IF agr_name[] IS INITIAL. EXIT. ENDIF.
  ENDDO.
  SORT gt_sel_all BY role.
  DELETE ADJACENT DUPLICATES FROM gt_sel_all COMPARING role.
  IF gt_sel_all IS INITIAL.
    MESSAGE s244(s#). RETURN.
  ELSEIF gf_sap_only EQ 'Y'.
*   Eliminating roles outside SAP name space
    LOOP AT gt_sel_all ASSIGNING <role_sel>.
      gd_role = <role_sel>-role.
      PERFORM excl_role_outside_sap IN PROGRAM saplprgn
                                    CHANGING gd_role.
      IF gd_role EQ space.
        DELETE gt_sel_all.
      ENDIF.
    ENDLOOP.
    IF gt_sel_all IS INITIAL.
      MESSAGE s168(s#). RETURN.
    ENDIF.
  ENDIF.

* Filling separate tables for collective, single and invalid roles as
* well as for short texts of all roles
  LOOP AT gt_sel_all ASSIGNING <role_sel>.
    CLEAR: gs_validity-type, gs_validity-error.
    MOVE-CORRESPONDING <role_sel> TO gs_validity.
    MOVE-CORRESPONDING <role_sel> TO gs_rec_role.
    IF <role_sel>-fl_typ EQ space.
      gs_validity-error = gc_ty.
      APPEND gs_validity TO gt_validity.
      APPEND gs_validity TO gt_log_all.
    ELSE.
      IF <role_sel>-fl_val EQ 'X'.
        APPEND gs_rec_role TO gt_cols_rec_n.
      ELSE.
        gs_validity-type = 'S'.
        APPEND gs_rec_role TO gt_sgls_rec_n.
        APPEND gs_validity TO gt_validity.
      ENDIF.
    ENDIF.
    APPEND INITIAL LINE TO gt_texts ASSIGNING <text>.
    MOVE-CORRESPONDING <role_sel> TO <text>.
  ENDLOOP.
  FREE gt_sel_all.

* II. Checking existing recordings

* Copying the validity table and the recording settings to function
* group PRGN
  PERFORM copy_validity_table IN PROGRAM saplprgn USING gt_validity.
  PERFORM imp_rec_settings    IN PROGRAM saplprgn
                                 USING gf_scc4_actv space
                                       comp_rol profiles person users.
  PERFORM init_opt_log_4_sgls IN PROGRAM saplprgn
                              USING gt_sgls_rec_n.
  CLEAR gd_request.
  IF gf_scc4_actv EQ space.
    PERFORM sel_req_in_dialog IN PROGRAM saplprgn
                              CHANGING gd_request gf_cancel.
    IF gf_cancel NE space. RETURN. ENDIF.
    PERFORM read_roles_from_req(saplprgn) USING gd_request 'X'.
    PERFORM chk_cols IN PROGRAM saplprgn
                     USING    gd_request
                     CHANGING gt_cols_rec_n gt_log_all.
    PERFORM chk_sgls IN PROGRAM saplprgn
                     USING    gd_request
                     CHANGING gt_sgls_rec_n gt_log_all.
  ELSE.
    CLEAR gd_req_tmp.
    PERFORM chk_cols_with_scc4 IN PROGRAM saplprgn
                               CHANGING gt_cols_rec_n gt_log_all
                                        gf_error.
    PERFORM chk_sgls_with_scc4 IN PROGRAM saplprgn
                               USING    space space
                               CHANGING gd_req_tmp               "Dummy
                                        gt_sgls_rec_n gt_log_all
                                        gt_log_tmp.              "Dummy
*   Checking conflicts among all derived roles per original role
    PERFORM chk_cnfl_all_hier IN PROGRAM saplprgn
                              CHANGING gt_sgls_rec_n gt_cols_rec_n
                                       gt_log_all
                                       gf_error.
*   Separating collective and single roles without fixed request
    LOOP AT gt_cols_rec_n ASSIGNING <rec> WHERE rqst NE space.
      APPEND <rec> TO gt_cols_rec_o.
      DELETE gt_cols_rec_n.
    ENDLOOP.
    LOOP AT gt_sgls_rec_n ASSIGNING <rec> WHERE rqst NE space.
      APPEND <rec> TO gt_sgls_rec_o.
      DELETE gt_sgls_rec_n.
    ENDLOOP.
    IF comp_rol EQ 'X'.
*     Checking conflicts due to single roles assigned to several
*     collective roles with fixed request
      PERFORM chk_cnfl_depnd_cols IN PROGRAM saplprgn
                                  CHANGING gt_cols_rec_o gt_cols_rec_n
                                           gt_sgls_rec_o gt_sgls_rec_n
                                           gt_log_all
                                           gf_error.
      PERFORM show_reqs_of_dep_cols IN PROGRAM saplprgn
                                    USING    testmode
                                    CHANGING gt_cols_rec_o gf_cancel.
      IF testmode EQ space AND gf_cancel EQ 'X'.
        MESSAGE s232(s#). RETURN.
      ENDIF.
    ENDIF.
*   Extracting list of old requests
    gt_old_reqs = gt_cols_rec_o.
    APPEND LINES OF gt_sgls_rec_o TO gt_old_reqs.
    SORT gt_old_reqs BY rqst.
    DELETE ADJACENT DUPLICATES FROM gt_old_reqs COMPARING rqst.
    SORT: gt_cols_rec_o BY rqst, gt_sgls_rec_o BY rqst.
  ENDIF.

* III. Role recording

  IF testmode EQ 'X'.
    CLEAR csol_eva.
  ENDIF.
  IF csol_eva EQ space.
    gf_all_or_no = 'X'.
*   Setting the global flag for recording all roles per request at once
    PERFORM imp_rec_settings IN PROGRAM saplprgn
                             USING gf_scc4_actv 'X'
                                   comp_rol profiles person users.
  ENDIF.

* a) Recording all roles with requests determined by existing records
*    (GT_OLD_REQS filled only for active SCC4 evaluation)
  LOOP AT gt_old_reqs ASSIGNING <req>.
    CLEAR: gt_cols_1_req, gt_sgls_1_req.
*   Collective roles
    READ TABLE gt_cols_rec_o WITH KEY rqst = <req>-rqst
                             TRANSPORTING NO FIELDS BINARY SEARCH.
    IF sy-subrc EQ 0.
      LOOP AT gt_cols_rec_o ASSIGNING <rec> FROM sy-tabix.
        IF <rec>-rqst NE <req>-rqst. EXIT. ENDIF.
        APPEND <rec> TO gt_cols_1_req.
      ENDLOOP.
      IF testmode EQ space.
        PERFORM chk_and_prep_req_4_rec IN PROGRAM saplprgn
                                       USING    <req>-rqst 'C' space
                                       CHANGING gt_cols_1_req
                                                gt_log_all.
      ENDIF.
      LOOP AT gt_cols_1_req ASSIGNING <rec>.
        PERFORM rec_1_col IN PROGRAM saplprgn CHANGING <rec> gt_log_all.
        IF <rec> IS INITIAL.
          DELETE gt_cols_1_req.
        ENDIF.
      ENDLOOP.
    ENDIF.
*   Single roles
    READ TABLE gt_sgls_rec_o WITH KEY rqst = <req>-rqst
                             TRANSPORTING NO FIELDS BINARY SEARCH.
    IF sy-subrc EQ 0.
      LOOP AT gt_sgls_rec_o ASSIGNING <rec> FROM sy-tabix.
        IF <rec>-rqst NE <req>-rqst. EXIT. ENDIF.
        APPEND <rec> TO gt_sgls_1_req.
      ENDLOOP.
      IF testmode EQ space.
        PERFORM chk_and_prep_req_4_rec IN PROGRAM saplprgn
                                       USING    <req>-rqst 'S' space
                                       CHANGING gt_sgls_1_req
                                                gt_log_all.
      ENDIF.
      PERFORM rec_sgl_roles IN PROGRAM saplprgn CHANGING gt_sgls_1_req
                                                         gt_log_all.
    ENDIF.
    IF gf_all_or_no EQ 'X'.
      CLEAR gf_error.
      IF testmode EQ space.
        PERFORM rec_all_roles_at_once IN PROGRAM saplprgn
                                      USING    <req>-rqst 'X'
                                      CHANGING gt_log_all gf_error.
      ELSE.
        PERFORM rec_simulation IN PROGRAM saplprgn USING <req>-rqst.
      ENDIF.
      IF gf_error EQ 'X'.
        IF comp_rol EQ 'X'.
*         Updating error buffer due to unrecorded single roles
          LOOP AT gt_cols_1_req ASSIGNING <rec> WHERE inh_role = 'R'.
            gd_msgv = <rec>-role.
            PERFORM log_rec_error IN PROGRAM saplprgn
                                  USING <rec>-role gc_no_rec 'O'
                                        'S#' 595 gd_msgv
                                                 space space space.
          ENDLOOP.
          IF 1 = 0. MESSAGE s595(s#) WITH gd_msgv. ENDIF.
        ENDIF.
      ELSE.
        IF comp_rol EQ 'X'.
*         Adding log entries for single roles as far as missing
          LOOP AT gt_cols_1_req ASSIGNING <rec>.
            <rec>-rqst = <req>-rqst.
            PERFORM upd_sgl_logs_4_col_if_all_ok IN PROGRAM saplprgn
                                                 USING    <rec>-role
                                                          <req>-rqst
                                                 CHANGING gt_log_all.
          ENDLOOP.
        ENDIF.
        PERFORM upd_sgl_logs_if_all_ok IN PROGRAM saplprgn
                                       USING    gt_sgls_1_req <req>-rqst
                                       CHANGING gt_log_all.
*       Adding log entries for collective roles previously unrecorded
        DELETE gt_cols_1_req WHERE inh_role = 'R'.
        PERFORM upd_log IN PROGRAM saplprgn
                        USING    gt_cols_1_req 'C' space
                        CHANGING gt_log_all.
      ENDIF.
    ELSE.
*     Updating flags required for After-Import method
      PERFORM upd_yel_yin_flags IN PROGRAM saplprgn.
*     Deleting single roles separately recorded from collective role
*     error log
      PERFORM clean_up_coll_logs IN PROGRAM saplprgn
                                 CHANGING gt_log_all.
    ENDIF.
  ENDLOOP.

* b) Recording all roles without determined request
  IF NOT gt_cols_rec_n IS INITIAL OR NOT gt_sgls_rec_n IS INITIAL.
    IF testmode EQ space.
      IF gd_request EQ space.
*       Request selection
        PERFORM sel_req_in_dialog IN PROGRAM saplprgn
                                  CHANGING gd_request gf_cancel.
        IF gf_cancel NE space.
          IF gt_log_all IS INITIAL.
*           No new records yet => program termination
            MESSAGE s232(s#). RETURN.
          ELSE.
            PERFORM upd_log IN PROGRAM saplprgn
                            USING    gt_cols_rec_n 'C' 'C'
                            CHANGING gt_log_all.
            PERFORM upd_log IN PROGRAM saplprgn
                            USING    gt_sgls_rec_n 'S' 'C'
                            CHANGING gt_log_all.
            CLEAR: gt_cols_rec_n, gt_sgls_rec_n.
          ENDIF.
        ENDIF.
      ENDIF.
      LOOP AT gt_cols_rec_n ASSIGNING <rec>.
        <rec>-rqst = gd_request.
        PERFORM rec_1_col IN PROGRAM saplprgn CHANGING <rec> gt_log_all.
        IF <rec> IS INITIAL.
          DELETE gt_cols_rec_n.
        ENDIF.
      ENDLOOP.
      LOOP AT gt_sgls_rec_n ASSIGNING <rec>.
        <rec>-rqst = gd_request.
      ENDLOOP.
      PERFORM rec_sgl_roles IN PROGRAM saplprgn CHANGING gt_sgls_rec_n
                                                         gt_log_all.
    ENDIF.
    IF gf_all_or_no EQ 'X'.
      CLEAR gf_error.
      IF testmode EQ space.
        PERFORM rec_all_roles_at_once IN PROGRAM saplprgn
                                      USING    gd_request 'X'
                                      CHANGING gt_log_all gf_error.
      ENDIF.
      IF gf_error EQ space.
        PERFORM upd_log IN PROGRAM saplprgn
                        USING    gt_cols_rec_n 'C' space
                        CHANGING gt_log_all.
        IF comp_rol EQ 'X'.
          LOOP AT gt_cols_rec_n ASSIGNING <rec>.
            PERFORM upd_sgl_logs_4_col_if_all_ok IN PROGRAM saplprgn
                                                 USING    <rec>-role
                                                          gd_request
                                                 CHANGING gt_log_all.
          ENDLOOP.
        ENDIF.
        PERFORM upd_sgl_logs_if_all_ok IN PROGRAM saplprgn
                                       USING    gt_sgls_rec_n gd_request
                                       CHANGING gt_log_all.
      ENDIF.
    ELSE.
*     Updating flags required for After-Import method
      PERFORM upd_yel_yin_flags IN PROGRAM saplprgn.
*     Deleting single roles separately recorded from collective role
*     error log
      PERFORM clean_up_coll_logs IN PROGRAM saplprgn
                                 CHANGING gt_log_all.
    ENDIF.
  ENDIF.
  IF testmode EQ space.
*   Recording optional components of recorded roles
    PERFORM rec_opt_comp IN PROGRAM saplprgn USING gt_log_all.
  ELSE.
*   Leaving in buffer only roles actually recorded
    PERFORM revoke_rec_simulation IN PROGRAM saplprgn.
  ENDIF.

* IV. Output of the results

  CLEAR gt_output.

  get_icon 'ICON_GREEN_LIGHT' 'Role recorded'(100) gd_icon_green.
  IF testmode EQ space.
    get_icon 'ICON_YELLOW_LIGHT'
             'Role recorded but optional components missing'(099)
             gd_icon_yello.
    get_icon 'ICON_RED_LIGHT' 'Role not recorded'(101) gd_icon_red.
  ELSE.
    get_icon 'ICON_LIGHT_OUT'
             'Role record possible, free request selection'(095)
             gd_icon_grey.
    get_icon 'ICON_RED_LIGHT' 'Role record not possible'(097)
             gd_icon_red.
  ENDIF.
* a) Filling the output table
  LOOP AT gt_log_all ASSIGNING <log>.
    CLEAR gs_output.
    MOVE-CORRESPONDING <log> TO gs_output.
    CASE <log>-type.
      WHEN 'C'. gs_output-role_type = gd_icon_col.
      WHEN 'S'. gs_output-role_type = gd_icon_sgl.
    ENDCASE.
*   Short text
    READ TABLE gt_texts ASSIGNING <text> WITH KEY role = gs_output-role
                        BINARY SEARCH.
    IF sy-subrc EQ 0.
      gs_output-text = <text>-text.
    ELSE.
      SELECT SINGLE text INTO gs_output-text FROM agr_texts
                         WHERE agr_name = gs_output-role
                         AND   spras    = sy-langu
                         AND   line     = 0.
    ENDIF.
*   Error status and text
    IF <log>-error NE space.
      PERFORM err_txts_4_report_log IN PROGRAM saplprgn
                                    USING    <log>
                                    CHANGING gs_output-err_text.
      gs_output-status = gd_icon_red.
      CLEAR gs_output-rqst.
    ELSE.
      gs_output-status = gd_icon_green.
*     Checking failure of optional components
      IF testmode EQ 'X'.
        PERFORM msgs_4_opt_rec_errs IN PROGRAM saplprgn
                                    USING    space
                                    CHANGING <log> gt_ret_dummy.
        IF <log>-error NE space.
*         In test mode the only option to fail is the record of single
*         roles in collective roles.
          get_icon 'ICON_YELLOW_LIGHT'
                   'Collective role recorded but record of single roles not possible'(094)
                   gd_icon_yello.
          gs_output-status   = gd_icon_yello.
          gs_output-error    = <log>-error.
          gs_output-err_text = 'Record of single roles not possible'(093).
        ELSE.
          IF <log>-rqst NE space.
            PERFORM chk_role_recorded IN PROGRAM saplprgn
                                      USING    <log>-role <log>-rqst
                                      CHANGING gd_subrc.
            IF gd_subrc NE 0.
*             Role not yet recorded, but request determined
              get_icon 'ICON_YELLOW_LIGHT'
                       'Role record possible, request already determined'(096)
                       gd_icon_yello.
              gs_output-status = gd_icon_yello.
            ENDIF.
          ELSE.
            gs_output-status = gd_icon_grey.
          ENDIF.
        ENDIF.
      ELSE.
        PERFORM msgs_4_opt_rec_errs IN PROGRAM saplprgn
                                    USING    'R'
                                    CHANGING <log> gt_ret_dummy.
        IF <log>-error NE space.
          gs_output-status   = gd_icon_yello.
          gs_output-error    = <log>-error.
          gs_output-err_text = 'Error when recording optional components'(098).
        ENDIF.
      ENDIF.
    ENDIF.
    APPEND gs_output TO gt_output.
  ENDLOOP.

EXPORT gt_output = gt_output TO MEMORY ID 'TRZ'.

* b) Showing results in ALV
*  PERFORM display_output.




*&--------------------------------------------------------------------
*&      Form click_on_role
*&--------------------------------------------------------------------
FORM click_on_role USING i_row    TYPE i
                         i_column TYPE lvc_fname.

  DATA: ls_log TYPE type_log_tab.

  DATA: ld_msg_txt(100) TYPE c,
        ld_par1         TYPE symsgv,
        ld_par2         TYPE symsgv.

  CLEAR gs_output.
  READ TABLE gt_output INTO gs_output INDEX i_row.
  IF sy-subrc NE 0 OR i_column IS INITIAL. RETURN. ENDIF.

  IF gs_output-role IS INITIAL. RETURN. ENDIF.
  CASE i_column.
    WHEN 'ROLE'.
*     Call transaction PFCG in the display mode for the selected role
      gd_role = gs_output-role.

      cl_spcg_tools_public=>show_edit_agr( id_agr_name     = gd_role
                                           id_mode         = 'A'
                                           id_screen       = '1'
                                           id_view         = '0'
                                           id_one_new_mode = abap_true ).
      CLEAR gd_role.
    WHEN 'ERR_TEXT'.
      IF gs_output-err_text IS INITIAL. RETURN. ENDIF.

      MOVE-CORRESPONDING gs_output TO ls_log.
      CASE gs_output-role_type.
        WHEN gd_icon_col. ls_log-type = 'C'.
        WHEN gd_icon_sgl. ls_log-type = 'S'.
      ENDCASE.
      PERFORM add_msgs_4_report_log IN PROGRAM saplprgn USING ls_log
                                                              testmode.
  ENDCASE.

ENDFORM.                    "click_on_role

*&--------------------------------------------------------------------*
*&      Form  set_sort_alv
*&--------------------------------------------------------------------*
FORM set_sort_alv.

  DATA: lr_sorts TYPE REF TO cl_salv_sorts.   "sort information

  lr_sorts = gr_table->get_sorts( ).
  lr_sorts->clear( ).

  TRY.
      lr_sorts->add_sort( columnname = 'ROLE'
                          position   = 1
                          sequence   = if_salv_c_sort=>sort_up ).
    CATCH cx_salv_not_found cx_salv_existing cx_salv_data_error.
                                                        "#EC NO_HANDLER
  ENDTRY.

ENDFORM.                    "set_sort_alv

*&---------------------------------------------------------------------
*&      Form  create_alv_form_content_tol
*&---------------------------------------------------------------------
*  This routine creates the text on top of page.
*----------------------------------------------------------------------
FORM create_alv_form_content_tol
     CHANGING cr_content TYPE REF TO cl_salv_form_element.

  DATA: lr_grid TYPE REF TO cl_salv_form_layout_grid.

  DATA: ld_text(80) TYPE c,
        ld_nr_rows  TYPE i VALUE 0.

  CREATE OBJECT lr_grid.

  CLEAR ld_text.
  IF testmode EQ 'X'.
    ld_text = 'Simulation of role record:'(127).
    ADD 1 TO ld_nr_rows.
    lr_grid->create_label( row    = ld_nr_rows
                           column = 1
                           text   = ld_text ).
  ENDIF.
* Checking for green lights
  READ TABLE gt_output WITH KEY status = gd_icon_green
                       TRANSPORTING NO FIELDS.
  IF sy-subrc EQ 0.
    IF gf_scc4_actv NE space.
      ld_text = 'Roles marked green were successfully recorded.'(124).
    ELSE.
      ld_text = 'Request &1 contains all roles marked green.'(122).
      REPLACE '&1' WITH gd_request INTO ld_text.
    ENDIF.
    ADD 1 TO ld_nr_rows.
    lr_grid->create_label( row    = ld_nr_rows
                           column = 1
                           text   = ld_text ).
  ENDIF.
* Checking for yellow lights
  READ TABLE gt_output WITH KEY status = gd_icon_yello
                       TRANSPORTING NO FIELDS.
  IF sy-subrc EQ 0.
    IF testmode EQ space.
      ld_text = 'For roles marked yellow optional components are missing.'(123).
    ELSE.
      ld_text = 'For roles marked yellow note the text of status display.'(125).
    ENDIF.
    ADD 1 TO ld_nr_rows.
    lr_grid->create_label( row    = ld_nr_rows
                           column = 1
                           text   = ld_text ).
  ENDIF.
  IF gf_scc4_actv NE space AND testmode EQ 'X'.
*   Existence check for roles with free request selection
    READ TABLE gt_output WITH KEY status = gd_icon_grey
                         TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      ld_text = 'For roles marked yellow the request can be freely chosen.'(126).
      ADD 1 TO ld_nr_rows.
      lr_grid->create_label( row    = ld_nr_rows
                             column = 1
                             text   = ld_text ).
    ENDIF.
  ENDIF.

  IF ld_text EQ space.
*   Red lights are occurring throughout.
    ld_text = 'No roles can be transported.'(121).
    ADD 1 TO ld_nr_rows.
    lr_grid->create_label( row    = ld_nr_rows
                           column = 1
                           text   = ld_text ).
  ENDIF.

  cr_content = lr_grid.

ENDFORM.                    " create_alv_form_content_tol
