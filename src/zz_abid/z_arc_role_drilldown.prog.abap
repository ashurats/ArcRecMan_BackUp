*&---------------------------------------------------------------------------------*
*& Report Z_ARC_ROLE_DRILLDOWN
*& Description: Hierarchical ALV Tree for Composite Role -> Single Role -> T-Codes
*&---------------------------------------------------------------------------------*
REPORT z_arc_role_drilldown.

***----------------------------------------------------------------------*
*** Database Tables
***----------------------------------------------------------------------*
**TABLES: usr02, agr_agrs, agr_1251.
**
***----------------------------------------------------------------------*
*** Global Variables for Selection Screen Titles
***----------------------------------------------------------------------*
**DATA: gv_rad TYPE c LENGTH 50,
**      gv_t_usr TYPE c LENGTH 50,
**      gv_t_rol TYPE c LENGTH 50.
**
***----------------------------------------------------------------------*
*** Selection Screen
***----------------------------------------------------------------------*
**SELECTION-SCREEN BEGIN OF BLOCK b_rad WITH FRAME TITLE gv_rad1.
**  PARAMETERS: p_user RADIOBUTTON GROUP g1 USER-COMMAND ucomm DEFAULT 'X',
**              p_role RADIOBUTTON GROUP g1.
**SELECTION-SCREEN END OF BLOCK b_rad.
**
**SELECTION-SCREEN BEGIN OF BLOCK b_usr WITH FRAME TITLE gv_usr1.
**  PARAMETERS: p_uname TYPE usr02-bname DEFAULT sy-uname MODIF ID usr.
**SELECTION-SCREEN END OF BLOCK b_usr.
**
**SELECTION-SCREEN BEGIN OF BLOCK b_rol WITH FRAME TITLE gv_rol1.
**  PARAMETERS: p_comp TYPE agr_name MODIF ID rol.
**  PARAMETERS: p_all  AS CHECKBOX DEFAULT 'X' MODIF ID rol.
**SELECTION-SCREEN END OF BLOCK b_rol.
**
***----------------------------------------------------------------------*
*** Types & Data: USER Report
***----------------------------------------------------------------------*
**TYPES: BEGIN OF ty_role_info,
**         uname    TYPE xubname,
**         agr_name TYPE agr_name,
**         from_dat TYPE dats,
**         to_dat   TYPE dats,
**         text     TYPE agr_title,
**       END OF ty_role_info.
**
**DATA: gt_user_roles TYPE TABLE OF ty_role_info,
**      gs_user_role  TYPE ty_role_info.
**
***----------------------------------------------------------------------*
*** Types & Data: ROLE Report
***----------------------------------------------------------------------*
**TYPES: BEGIN OF ty_single_role,
**         agr_name  TYPE agr_agrs-agr_name,
**         child_agr TYPE agr_agrs-child_agr,
**       END OF ty_single_role.
**
**TYPES: BEGIN OF ty_auth,
**         agr_name TYPE agr_1251-agr_name,
**         object   TYPE agr_1251-object,
**         field    TYPE agr_1251-field,
**         low      TYPE agr_1251-low,
**         high     TYPE agr_1251-high,
**       END OF ty_auth.
**
**TYPES: BEGIN OF ty_output,
**         node_type TYPE char20,
**         role_name TYPE agr_name,
**         object    TYPE agr_1251-object,
**         field     TYPE agr_1251-field,
**         low       TYPE agr_1251-low,
**         high      TYPE agr_1251-high,
**       END OF ty_output.
**
**TYPES: BEGIN OF ty_node_map,
**         node_key  TYPE salv_de_node_key,
**         node_type TYPE char20,
**         role_name TYPE agr_name,
**       END OF ty_node_map.
**
**TYPES: BEGIN OF ty_obj_role,
**         object   TYPE agr_1251-object,
**         agr_name TYPE agr_1251-agr_name,
**       END OF ty_obj_role.
**
**TYPES: BEGIN OF ty_tobjt,
**         object TYPE tobjt-object,
**         ttext  TYPE tobjt-ttext,
**       END OF ty_tobjt.
**
**TYPES: BEGIN OF ty_tactt,
**         actvt TYPE tactt-actvt,
**         ltext TYPE tactt-ltext,
**       END OF ty_tactt.
**
**DATA: gt_single_roles TYPE STANDARD TABLE OF ty_single_role,
**      gt_auth         TYPE STANDARD TABLE OF ty_auth,
**      gs_auth         TYPE ty_auth,
**      gt_output       TYPE STANDARD TABLE OF ty_output,
**      gs_output       TYPE ty_output,
**      gt_node_map     TYPE STANDARD TABLE OF ty_node_map,
**      gs_node_map     TYPE ty_node_map,
**      gt_tobjt        TYPE STANDARD TABLE OF ty_tobjt,
**      gs_tobjt        TYPE ty_tobjt,
**      gt_tactt        TYPE STANDARD TABLE OF ty_tactt,
**      gs_tactt        TYPE ty_tactt.
**
***----------------------------------------------------------------------*
*** SALV Tree Objects (Shared/Generic References)
***----------------------------------------------------------------------*
**DATA: go_tree   TYPE REF TO cl_salv_tree,
**      go_nodes  TYPE REF TO cl_salv_nodes,
**      go_node   TYPE REF TO cl_salv_node,
**      go_events TYPE REF TO cl_salv_events_tree.
**
***----------------------------------------------------------------------*
*** Event Handler Class (Role Report PFCG Drilldown)
***----------------------------------------------------------------------*
**CLASS lcl_event_handler DEFINITION.
**  PUBLIC SECTION.
**    METHODS on_double_click
**      FOR EVENT double_click OF cl_salv_events_tree
**      IMPORTING node_key columnname.
**ENDCLASS.
**
**CLASS lcl_event_handler IMPLEMENTATION.
**  METHOD on_double_click.
**    DATA: ls_node_map TYPE ty_node_map,
**          lv_role     TYPE agr_name.
**
**    READ TABLE gt_node_map INTO ls_node_map WITH KEY node_key = node_key.
**    IF sy-subrc <> 0.
**      RETURN.
**    ENDIF.
**
**    " Only Role node should open PFCG
**    IF ls_node_map-node_type <> 'Role'.
**      RETURN.
**    ENDIF.
**
**    lv_role = ls_node_map-role_name.
**    IF lv_role IS INITIAL.
**      RETURN.
**    ENDIF.
**
**    PERFORM open_pfcg_auth_tab USING lv_role.
**  ENDMETHOD.
**ENDCLASS.
**
**DATA: go_handler TYPE REF TO lcl_event_handler.
**
***----------------------------------------------------------------------*
*** Initialization
***----------------------------------------------------------------------*
**INITIALIZATION.
**  gv_rad = 'Select Report Mode'.
**  gv_t_usr = 'User -> Roles Hierarchy'.
**  gv_t_rol = 'Composite Role -> Auth Hierarchy'.
**
***----------------------------------------------------------------------*
*** Dynamic Screen Modification
***----------------------------------------------------------------------*
**AT SELECTION-SCREEN OUTPUT.
**  LOOP AT SCREEN.
**    IF p_user = 'X' AND screen-group1 = 'ROL'.
**      screen-active = 0.
**    ELSEIF p_role = 'X' AND screen-group1 = 'USR'.
**      screen-active = 0.
**    ENDIF.
**    MODIFY SCREEN.
**  ENDLOOP.
**
***----------------------------------------------------------------------*
*** Start of Selection
***----------------------------------------------------------------------*
**START-OF-SELECTION.
**
**  IF p_user = 'X'.
**    " --- USER REPORT LOGIC ---
**    IF p_uname IS INITIAL.
**      MESSAGE 'Please enter a User ID.' TYPE 'S' DISPLAY LIKE 'E'.
**      EXIT.
**    ENDIF.
**
**    PERFORM get_user_data.
**    IF gt_user_roles IS NOT INITIAL.
**      PERFORM build_user_tree.
**    ELSE.
**      MESSAGE 'No roles found for the specified user.' TYPE 'S' DISPLAY LIKE 'E'.
**    ENDIF.
**
**  ELSEIF p_role = 'X'.
**    " --- ROLE REPORT LOGIC ---
**    IF p_comp IS INITIAL.
**      MESSAGE 'Please enter a Composite Role.' TYPE 'S' DISPLAY LIKE 'E'.
**      EXIT.
**    ENDIF.
**
**    PERFORM get_role_data.
**    IF gt_single_roles IS INITIAL.
**      MESSAGE 'No single roles found for this composite role.' TYPE 'I'.
**      EXIT.
**    ENDIF.
**    PERFORM build_role_tree.
**
**  ENDIF.
**
***======================================================================*
*** FORMS FOR USER REPORT
***======================================================================*
**FORM get_user_data.
**  SELECT a~uname,
**         a~agr_name,
**         a~from_dat,
**         a~to_dat,
**         t~text
**    INTO TABLE @gt_user_roles
**    FROM agr_users AS a
**    LEFT OUTER JOIN agr_texts AS t
**      ON  a~agr_name = t~agr_name
**      AND t~spras    = @sy-langu
**      AND t~line     = 0
**    WHERE a~uname = @p_uname.
**ENDFORM.
**
**FORM build_user_tree.
**  DATA: lt_empty_table TYPE TABLE OF ty_role_info,
**        lv_root_key    TYPE salv_de_node_key.
**
**  TRY.
**      cl_salv_tree=>factory(
**        IMPORTING r_salv_tree = go_tree
**        CHANGING  t_table     = lt_empty_table ).
**
**      go_nodes = go_tree->get_nodes( ).
**
**      DATA(ls_root_data) = VALUE ty_role_info( uname = p_uname ).
**
**      go_node = go_nodes->add_node(
**        related_node   = ''
**        relationship   = cl_gui_column_tree=>relat_last_child
**        data_row       = ls_root_data
**        text           = CONV #( p_uname )
**        folder         = abap_true ).
**
**      lv_root_key = go_node->get_key( ).
**
**      LOOP AT gt_user_roles INTO gs_user_role.
**        go_nodes->add_node(
**          related_node = lv_root_key
**          relationship = cl_gui_column_tree=>relat_last_child
**          data_row     = gs_user_role
**          text         = CONV #( gs_user_role-agr_name ) ).
**      ENDLOOP.
**
**      go_nodes->expand_all( ).
**      DATA(lo_columns) = go_tree->get_columns( ).
**      lo_columns->set_optimize( abap_true ).
**
**      go_tree->display( ).
**
**    CATCH cx_salv_error. "cx_salv_msg.
**      MESSAGE 'Error generating User Tree.' TYPE 'E'.
**  ENDTRY.
**ENDFORM.
**
***======================================================================*
*** FORMS FOR ROLE REPORT
***======================================================================*
**FORM get_role_data.
**  CLEAR: gt_single_roles, gt_auth, gt_output, gt_node_map, gt_tobjt, gt_tactt.
**
**  SELECT agr_name child_agr
**    FROM agr_agrs
**    INTO TABLE gt_single_roles
**    WHERE agr_name = p_comp.
**
**  IF gt_single_roles IS INITIAL.
**    RETURN.
**  ENDIF.
**
**  IF p_all = 'X'.
**    SELECT agr_name object field low high
**      FROM agr_1251
**      INTO TABLE gt_auth
**      FOR ALL ENTRIES IN gt_single_roles
**      WHERE agr_name = gt_single_roles-child_agr.
**  ELSE.
**    SELECT agr_name object field low high
**      FROM agr_1251
**      INTO TABLE gt_auth
**      FOR ALL ENTRIES IN gt_single_roles
**      WHERE agr_name = gt_single_roles-child_agr
**        AND object   = 'S_TCODE'
**        AND field    = 'TCD'.
**  ENDIF.
**
**  IF gt_auth IS NOT INITIAL.
**    SELECT object ttext
**      FROM tobjt
**      INTO TABLE gt_tobjt
**      FOR ALL ENTRIES IN gt_auth
**      WHERE object = gt_auth-object AND langu = sy-langu.
**
**    SELECT actvt ltext
**      FROM tactt
**      INTO TABLE gt_tactt
**      WHERE spras = sy-langu.
**  ENDIF.
**
**  SORT gt_auth BY object agr_name field low high.
**  SORT gt_tobjt BY object.
**  SORT gt_tactt BY actvt.
**ENDFORM.
**
**FORM build_role_tree.
**  DATA: lv_obj_key   TYPE salv_de_node_key,
**        lv_role_key  TYPE salv_de_node_key,
**        lv_field_key TYPE salv_de_node_key.
**
**  DATA: lv_obj_text   TYPE lvc_value,
**        lv_role_text  TYPE lvc_value,
**        lv_field_text TYPE lvc_value,
**        lv_low_text   TYPE string,
**        lv_high_text  TYPE string.
**
**  DATA: lt_objects   TYPE STANDARD TABLE OF agr_1251-object,
**        lv_object    TYPE agr_1251-object,
**        lt_obj_roles TYPE STANDARD TABLE OF ty_obj_role,
**        ls_obj_role  TYPE ty_obj_role.
**
**  LOOP AT gt_auth INTO gs_auth.
**    APPEND gs_auth-object TO lt_objects.
**    ls_obj_role-object   = gs_auth-object.
**    ls_obj_role-agr_name = gs_auth-agr_name.
**    APPEND ls_obj_role TO lt_obj_roles.
**  ENDLOOP.
**
**  SORT lt_objects.
**  DELETE ADJACENT DUPLICATES FROM lt_objects.
**  SORT lt_obj_roles BY object agr_name.
**  DELETE ADJACENT DUPLICATES FROM lt_obj_roles COMPARING object agr_name.
**
**  TRY.
**      cl_salv_tree=>factory(
**        IMPORTING r_salv_tree = go_tree
**        CHANGING  t_table     = gt_output ).
**
**      go_nodes = go_tree->get_nodes( ).
**
**      go_events = go_tree->get_event( ).
**      CREATE OBJECT go_handler.
**      SET HANDLER go_handler->on_double_click FOR go_events.
**
**      LOOP AT lt_objects INTO lv_object.
**        CLEAR gs_output.
**        gs_output-node_type = 'Object'.
**        gs_output-object    = lv_object.
**
**        READ TABLE gt_tobjt INTO gs_tobjt WITH KEY object = lv_object BINARY SEARCH.
**        IF sy-subrc = 0.
**          CONCATENATE lv_object '-' gs_tobjt-ttext INTO lv_obj_text SEPARATED BY space.
**        ELSE.
**          lv_obj_text = lv_object.
**        ENDIF.
**
**        go_node = go_nodes->add_node(
**          related_node = ''
**          relationship = cl_gui_column_tree=>relat_last_child
**          text         = lv_obj_text
**          data_row     = gs_output ).
**
**        lv_obj_key = go_node->get_key( ).
**
**        CLEAR gs_node_map.
**        gs_node_map-node_key  = lv_obj_key.
**        gs_node_map-node_type = 'Object'.
**        APPEND gs_node_map TO gt_node_map.
**
**        LOOP AT lt_obj_roles INTO ls_obj_role WHERE object = lv_object.
**          CLEAR gs_output.
**          gs_output-node_type = 'Role'.
**          gs_output-role_name = ls_obj_role-agr_name.
**
**          lv_role_text = ls_obj_role-agr_name.
**
**          go_node = go_nodes->add_node(
**            related_node = lv_obj_key
**            relationship = cl_gui_column_tree=>relat_last_child
**            text         = lv_role_text
**            data_row     = gs_output ).
**
**          lv_role_key = go_node->get_key( ).
**
**          CLEAR gs_node_map.
**          gs_node_map-node_key  = lv_role_key.
**          gs_node_map-node_type = 'Role'.
**          gs_node_map-role_name = ls_obj_role-agr_name.
**          APPEND gs_node_map TO gt_node_map.
**
**          LOOP AT gt_auth INTO gs_auth WHERE object   = lv_object
**                                         AND agr_name = ls_obj_role-agr_name.
**            CLEAR gs_output.
**            gs_output-node_type = 'Field'.
**            gs_output-role_name = gs_auth-agr_name.
**            gs_output-object    = gs_auth-object.
**            gs_output-field     = gs_auth-field.
**            gs_output-low       = gs_auth-low.
**            gs_output-high      = gs_auth-high.
**
**            CLEAR: lv_field_text, lv_low_text, lv_high_text.
**
**            IF gs_auth-field = 'ACTVT'.
**              READ TABLE gt_tactt INTO gs_tactt WITH KEY actvt = gs_auth-low BINARY SEARCH.
**              IF sy-subrc = 0.
**                CONCATENATE gs_auth-low '(' gs_tactt-ltext ')' INTO lv_low_text.
**              ELSE.
**                lv_low_text = gs_auth-low.
**              ENDIF.
**            ELSE.
**              lv_low_text = gs_auth-low.
**            ENDIF.
**
**            CONCATENATE gs_auth-field '/' lv_low_text INTO lv_field_text SEPARATED BY space.
**
**            IF gs_auth-high IS NOT INITIAL.
**              IF gs_auth-field = 'ACTVT'.
**                READ TABLE gt_tactt INTO gs_tactt WITH KEY actvt = gs_auth-high BINARY SEARCH.
**                IF sy-subrc = 0.
**                  CONCATENATE gs_auth-high '(' gs_tactt-ltext ')' INTO lv_high_text.
**                ELSE.
**                  lv_high_text = gs_auth-high.
**                ENDIF.
**              ELSE.
**                lv_high_text = gs_auth-high.
**              ENDIF.
**              CONCATENATE lv_field_text '-' lv_high_text INTO lv_field_text SEPARATED BY space.
**            ENDIF.
**
**            go_node = go_nodes->add_node(
**              related_node = lv_role_key
**              relationship = cl_gui_column_tree=>relat_last_child
**              text         = lv_field_text
**              data_row     = gs_output ).
**
**            lv_field_key = go_node->get_key( ).
**
**            CLEAR gs_node_map.
**            gs_node_map-node_key  = lv_field_key.
**            gs_node_map-node_type = 'Field'.
**            gs_node_map-role_name = gs_auth-agr_name.
**            APPEND gs_node_map TO gt_node_map.
**          ENDLOOP.
**        ENDLOOP.
**      ENDLOOP.
**
**      DATA(lo_settings) = go_tree->get_tree_settings( ).
**      lo_settings->set_hierarchy_header( 'Hierarchy' ).
**      lo_settings->set_hierarchy_size( 70 ).
**
**      DATA(lo_columns) = go_tree->get_columns( ).
**      lo_columns->set_optimize( 'X' ).
**
**      go_tree->display( ).
**
**    CATCH cx_salv_msg INTO DATA(lx_msg).
**      MESSAGE lx_msg->get_text( ) TYPE 'E'.
**    CATCH cx_salv_not_found INTO DATA(lx_not_found).
**      MESSAGE lx_not_found->get_text( ) TYPE 'E'.
**  ENDTRY.
**ENDFORM.
**
***======================================================================*
*** BDC / PFCG Drilldown Routines (For Role Report)
***======================================================================*
**FORM open_pfcg_auth_tab USING pv_role TYPE agr_name.
**  DATA: lt_bdcdata TYPE STANDARD TABLE OF bdcdata,
**        ls_options TYPE ctu_params.
**
**  CLEAR lt_bdcdata.
**
**  PERFORM bdc_dynpro TABLES lt_bdcdata USING 'SAPLPRGN_TREE' '0100'.
**  PERFORM bdc_field  TABLES lt_bdcdata USING 'BDC_CURSOR' 'AGR_NAME_NEU'.
**  PERFORM bdc_field  TABLES lt_bdcdata USING 'AGR_NAME_NEU' pv_role.
**  PERFORM bdc_field  TABLES lt_bdcdata USING 'BDC_OKCODE' '=CHAN'.
**
**  PERFORM bdc_dynpro TABLES lt_bdcdata USING 'SAPLPRGN_TREE' '0101'.
**  PERFORM bdc_field  TABLES lt_bdcdata USING 'BDC_OKCODE' '=AUTH'.
**
**  CLEAR ls_options.
**  ls_options-dismode = 'E'.
**  ls_options-updmode = 'S'.
**  ls_options-defsize = 'X'.
**
**  CALL TRANSACTION 'PFCG' USING lt_bdcdata OPTIONS FROM ls_options.
**ENDFORM.
**
**FORM bdc_dynpro TABLES pt_bdcdata STRUCTURE bdcdata USING pv_program pv_dynpro.
**  DATA ls_bdcdata TYPE bdcdata.
**  CLEAR ls_bdcdata.
**  ls_bdcdata-program  = pv_program.
**  ls_bdcdata-dynpro   = pv_dynpro.
**  ls_bdcdata-dynbegin = 'X'.
**  APPEND ls_bdcdata TO pt_bdcdata.
**ENDFORM.
**
**FORM bdc_field TABLES pt_bdcdata STRUCTURE bdcdata USING pv_fnam pv_fval.
**  DATA ls_bdcdata TYPE bdcdata.
**  CLEAR ls_bdcdata.
**  ls_bdcdata-fnam = pv_fnam.
**  ls_bdcdata-fval = pv_fval.
**  APPEND ls_bdcdata TO pt_bdcdata.
**ENDFORM.




*----------------------------------------------------------------------*
* Database Tables
*----------------------------------------------------------------------*
TABLES: usr02, agr_agrs, agr_1251.

*----------------------------------------------------------------------*
* Global Variables for Selection Screen Titles
*----------------------------------------------------------------------*
DATA: gv_t_rad TYPE c LENGTH 50,
      gv_t_usr TYPE c LENGTH 50,
      gv_t_rol TYPE c LENGTH 50.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b_rad WITH FRAME TITLE t_rad.
  PARAMETERS: p_user RADIOBUTTON GROUP g1 USER-COMMAND ucomm DEFAULT 'X',
              p_role RADIOBUTTON GROUP g1.
SELECTION-SCREEN END OF BLOCK b_rad.

SELECTION-SCREEN BEGIN OF BLOCK b_usr WITH FRAME TITLE t_usr.
  PARAMETERS: p_uname TYPE usr02-bname DEFAULT sy-uname MODIF ID usr.
SELECTION-SCREEN END OF BLOCK b_usr.

SELECTION-SCREEN BEGIN OF BLOCK b_rol WITH FRAME TITLE t_rol.
  PARAMETERS: p_comp TYPE agr_name MODIF ID rol.
  PARAMETERS: p_all  AS CHECKBOX DEFAULT 'X' MODIF ID rol.
SELECTION-SCREEN END OF BLOCK b_rol.

*----------------------------------------------------------------------*
* Types & Data: Shared & Mapping
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_node_map,
         node_key  TYPE salv_de_node_key,
         node_type TYPE char20,
         role_name TYPE agr_name,
       END OF ty_node_map.

DATA: gt_node_map TYPE STANDARD TABLE OF ty_node_map,
      gs_node_map TYPE ty_node_map.

*----------------------------------------------------------------------*
* Types & Data: USER Report
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_role_info,
         uname    TYPE xubname,
         agr_name TYPE agr_name,
         from_dat TYPE dats,
         to_dat   TYPE dats,
         text     TYPE agr_title,
       END OF ty_role_info.

DATA: gt_user_roles TYPE TABLE OF ty_role_info,
      gs_user_role  TYPE ty_role_info.

*----------------------------------------------------------------------*
* Types & Data: ROLE Report
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_single_role,
         agr_name  TYPE agr_agrs-agr_name,
         child_agr TYPE agr_agrs-child_agr,
       END OF ty_single_role.

TYPES: BEGIN OF ty_auth,
         agr_name TYPE agr_1251-agr_name,
         object   TYPE agr_1251-object,
         field    TYPE agr_1251-field,
         low      TYPE agr_1251-low,
         high     TYPE agr_1251-high,
       END OF ty_auth.

TYPES: BEGIN OF ty_output,
         node_type TYPE char20,
         role_name TYPE agr_name,
         object    TYPE agr_1251-object,
         field     TYPE agr_1251-field,
         low       TYPE agr_1251-low,
         high      TYPE agr_1251-high,
       END OF ty_output.

TYPES: BEGIN OF ty_obj_role,
         object   TYPE agr_1251-object,
         agr_name TYPE agr_1251-agr_name,
       END OF ty_obj_role.

TYPES: BEGIN OF ty_tobjt,
         object TYPE tobjt-object,
         ttext  TYPE tobjt-ttext,
       END OF ty_tobjt.

TYPES: BEGIN OF ty_tactt,
         actvt TYPE tactt-actvt,
         ltext TYPE tactt-ltext,
       END OF ty_tactt.

DATA: gt_single_roles TYPE STANDARD TABLE OF ty_single_role,
      gt_auth         TYPE STANDARD TABLE OF ty_auth,
      gs_auth         TYPE ty_auth,
      gt_output       TYPE STANDARD TABLE OF ty_output,
      gs_output       TYPE ty_output,
      gt_tobjt        TYPE STANDARD TABLE OF ty_tobjt,
      gs_tobjt        TYPE ty_tobjt,
      gt_tactt        TYPE STANDARD TABLE OF ty_tactt,
      gs_tactt        TYPE ty_tactt.

*----------------------------------------------------------------------*
* SALV Tree Objects (Shared/Generic References)
*----------------------------------------------------------------------*
DATA: go_tree   TYPE REF TO cl_salv_tree,
      go_nodes  TYPE REF TO cl_salv_nodes,
      go_node   TYPE REF TO cl_salv_node,
      go_events TYPE REF TO cl_salv_events_tree.

*----------------------------------------------------------------------*
* Event Handler Class (Double-Click Drilldown)
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_tree
      IMPORTING node_key columnname.
ENDCLASS.

CLASS lcl_event_handler IMPLEMENTATION.
  METHOD on_double_click.
    DATA: ls_node_map TYPE ty_node_map,
          lv_role     TYPE agr_name.

    READ TABLE gt_node_map INTO ls_node_map WITH KEY node_key = node_key.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Only Role node should open PFCG
    IF ls_node_map-node_type <> 'Role'.
      MESSAGE 'Please double-click directly on a Role name.' TYPE 'S'.
      RETURN.
    ENDIF.

    lv_role = ls_node_map-role_name.
    IF lv_role IS INITIAL.
      RETURN.
    ENDIF.

    " Route based on which report is active
    IF p_user = 'X'.
      PERFORM open_pfcg_display USING lv_role.
    ELSEIF p_role = 'X'.
      PERFORM open_pfcg_auth_tab USING lv_role.
    ENDIF.

  ENDMETHOD.
ENDCLASS.

DATA: go_handler TYPE REF TO lcl_event_handler.

*----------------------------------------------------------------------*
* Initialization
*----------------------------------------------------------------------*
INITIALIZATION.
  gv_t_rad = 'Select Report Mode'.
  gv_t_usr = 'User -> Roles Hierarchy'.
  gv_t_rol = 'Composite Role -> Auth Hierarchy'.

*----------------------------------------------------------------------*
* Dynamic Screen Modification
*----------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF p_user = 'X' AND screen-group1 = 'ROL'.
      screen-active = 0.
    ELSEIF p_role = 'X' AND screen-group1 = 'USR'.
      screen-active = 0.
    ENDIF.
    MODIFY SCREEN.
  ENDLOOP.

*----------------------------------------------------------------------*
* Start of Selection
*----------------------------------------------------------------------*
START-OF-SELECTION.

  IF p_user = 'X'.
    " --- USER REPORT LOGIC ---
    IF p_uname IS INITIAL.
      MESSAGE 'Please enter a User ID.' TYPE 'S' DISPLAY LIKE 'E'.
      EXIT.
    ENDIF.

    PERFORM get_user_data.
    IF gt_user_roles IS NOT INITIAL.
      PERFORM build_user_tree.
    ELSE.
      MESSAGE 'No roles found for the specified user.' TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.

  ELSEIF p_role = 'X'.
    " --- ROLE REPORT LOGIC ---
    IF p_comp IS INITIAL.
      MESSAGE 'Please enter a Composite Role.' TYPE 'S' DISPLAY LIKE 'E'.
      EXIT.
    ENDIF.

    PERFORM get_role_data.
    IF gt_single_roles IS INITIAL.
      MESSAGE 'No single roles found for this composite role.' TYPE 'I'.
      EXIT.
    ENDIF.
    PERFORM build_role_tree.

  ENDIF.

*======================================================================*
* FORMS FOR USER REPORT
*======================================================================*
FORM get_user_data.
  CLEAR gt_node_map.

  SELECT a~uname,
         a~agr_name,
         a~from_dat,
         a~to_dat,
         t~text
    INTO TABLE @gt_user_roles
    FROM agr_users AS a
    LEFT OUTER JOIN agr_texts AS t
      ON  a~agr_name = t~agr_name
      AND t~spras    = @sy-langu
      AND t~line     = 0
    WHERE a~uname = @p_uname.
ENDFORM.

FORM build_user_tree.
  DATA: lt_empty_table TYPE TABLE OF ty_role_info,
        lv_root_key    TYPE salv_de_node_key,
        lv_child_key   TYPE salv_de_node_key.

  TRY.
      cl_salv_tree=>factory(
        IMPORTING r_salv_tree = go_tree
        CHANGING  t_table     = lt_empty_table ).

      go_nodes = go_tree->get_nodes( ).

      " Register Event Handler for User Tree
      go_events = go_tree->get_event( ).
      IF go_handler IS NOT BOUND.
        CREATE OBJECT go_handler.
      ENDIF.
      SET HANDLER go_handler->on_double_click FOR go_events.

      " Root Node (User)
      DATA(ls_root_data) = VALUE ty_role_info( uname = p_uname ).

      go_node = go_nodes->add_node(
        related_node   = ''
        relationship   = cl_gui_column_tree=>relat_last_child
        data_row       = ls_root_data
        text           = CONV #( p_uname )
        folder         = abap_true ).

      lv_root_key = go_node->get_key( ).

      " Child Nodes (Roles)
      LOOP AT gt_user_roles INTO gs_user_role.
        go_node = go_nodes->add_node(
          related_node = lv_root_key
          relationship = cl_gui_column_tree=>relat_last_child
          data_row     = gs_user_role
          text         = CONV #( gs_user_role-agr_name ) ).

        " Map the node so double-click knows the role name
        lv_child_key = go_node->get_key( ).
        CLEAR gs_node_map.
        gs_node_map-node_key  = lv_child_key.
        gs_node_map-node_type = 'Role'.
        gs_node_map-role_name = gs_user_role-agr_name.
        APPEND gs_node_map TO gt_node_map.
      ENDLOOP.

      go_nodes->expand_all( ).
      DATA(lo_columns) = go_tree->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      go_tree->display( ).

    CATCH cx_salv_error. "cx_salv_msg.
      MESSAGE 'Error generating User Tree.' TYPE 'E'.
  ENDTRY.
ENDFORM.

*======================================================================*
* FORMS FOR ROLE REPORT
*======================================================================*
FORM get_role_data.
  CLEAR: gt_single_roles, gt_auth, gt_output, gt_node_map, gt_tobjt, gt_tactt.

  SELECT agr_name child_agr
    FROM agr_agrs
    INTO TABLE gt_single_roles
    WHERE agr_name = p_comp.

  IF gt_single_roles IS INITIAL.
    RETURN.
  ENDIF.

  IF p_all = 'X'.
    SELECT agr_name object field low high
      FROM agr_1251
      INTO TABLE gt_auth
      FOR ALL ENTRIES IN gt_single_roles
      WHERE agr_name = gt_single_roles-child_agr.
  ELSE.
    SELECT agr_name object field low high
      FROM agr_1251
      INTO TABLE gt_auth
      FOR ALL ENTRIES IN gt_single_roles
      WHERE agr_name = gt_single_roles-child_agr
        AND object   = 'S_TCODE'
        AND field    = 'TCD'.
  ENDIF.

  IF gt_auth IS NOT INITIAL.
    SELECT object ttext
      FROM tobjt
      INTO TABLE gt_tobjt
      FOR ALL ENTRIES IN gt_auth
      WHERE object = gt_auth-object AND langu = sy-langu.

    SELECT actvt ltext
      FROM tactt
      INTO TABLE gt_tactt
      WHERE spras = sy-langu.
  ENDIF.

  SORT gt_auth BY object agr_name field low high.
  SORT gt_tobjt BY object.
  SORT gt_tactt BY actvt.
ENDFORM.

FORM build_role_tree.
  DATA: lv_obj_key   TYPE salv_de_node_key,
        lv_role_key  TYPE salv_de_node_key,
        lv_field_key TYPE salv_de_node_key.

  DATA: lv_obj_text   TYPE lvc_value,
        lv_role_text  TYPE lvc_value,
        lv_field_text TYPE lvc_value,
        lv_low_text   TYPE string,
        lv_high_text  TYPE string.

  DATA: lt_objects   TYPE STANDARD TABLE OF agr_1251-object,
        lv_object    TYPE agr_1251-object,
        lt_obj_roles TYPE STANDARD TABLE OF ty_obj_role,
        ls_obj_role  TYPE ty_obj_role.

  LOOP AT gt_auth INTO gs_auth.
    APPEND gs_auth-object TO lt_objects.
    ls_obj_role-object   = gs_auth-object.
    ls_obj_role-agr_name = gs_auth-agr_name.
    APPEND ls_obj_role TO lt_obj_roles.
  ENDLOOP.

  SORT lt_objects.
  DELETE ADJACENT DUPLICATES FROM lt_objects.
  SORT lt_obj_roles BY object agr_name.
  DELETE ADJACENT DUPLICATES FROM lt_obj_roles COMPARING object agr_name.

  TRY.
      cl_salv_tree=>factory(
        IMPORTING r_salv_tree = go_tree
        CHANGING  t_table     = gt_output ).

      go_nodes = go_tree->get_nodes( ).

      go_events = go_tree->get_event( ).
      IF go_handler IS NOT BOUND.
        CREATE OBJECT go_handler.
      ENDIF.
      SET HANDLER go_handler->on_double_click FOR go_events.

      LOOP AT lt_objects INTO lv_object.
        CLEAR gs_output.
        gs_output-node_type = 'Object'.
        gs_output-object    = lv_object.

        READ TABLE gt_tobjt INTO gs_tobjt WITH KEY object = lv_object BINARY SEARCH.
        IF sy-subrc = 0.
          CONCATENATE lv_object '-' gs_tobjt-ttext INTO lv_obj_text SEPARATED BY space.
        ELSE.
          lv_obj_text = lv_object.
        ENDIF.

        go_node = go_nodes->add_node(
          related_node = ''
          relationship = cl_gui_column_tree=>relat_last_child
          text         = lv_obj_text
          data_row     = gs_output ).

        lv_obj_key = go_node->get_key( ).

        CLEAR gs_node_map.
        gs_node_map-node_key  = lv_obj_key.
        gs_node_map-node_type = 'Object'.
        APPEND gs_node_map TO gt_node_map.

        LOOP AT lt_obj_roles INTO ls_obj_role WHERE object = lv_object.
          CLEAR gs_output.
          gs_output-node_type = 'Role'.
          gs_output-role_name = ls_obj_role-agr_name.

          lv_role_text = ls_obj_role-agr_name.

          go_node = go_nodes->add_node(
            related_node = lv_obj_key
            relationship = cl_gui_column_tree=>relat_last_child
            text         = lv_role_text
            data_row     = gs_output ).

          lv_role_key = go_node->get_key( ).

          CLEAR gs_node_map.
          gs_node_map-node_key  = lv_role_key.
          gs_node_map-node_type = 'Role'.
          gs_node_map-role_name = ls_obj_role-agr_name.
          APPEND gs_node_map TO gt_node_map.

          LOOP AT gt_auth INTO gs_auth WHERE object   = lv_object
                                         AND agr_name = ls_obj_role-agr_name.
            CLEAR gs_output.
            gs_output-node_type = 'Field'.
            gs_output-role_name = gs_auth-agr_name.
            gs_output-object    = gs_auth-object.
            gs_output-field     = gs_auth-field.
            gs_output-low       = gs_auth-low.
            gs_output-high      = gs_auth-high.

            CLEAR: lv_field_text, lv_low_text, lv_high_text.

            IF gs_auth-field = 'ACTVT'.
              READ TABLE gt_tactt INTO gs_tactt WITH KEY actvt = gs_auth-low BINARY SEARCH.
              IF sy-subrc = 0.
                CONCATENATE gs_auth-low '(' gs_tactt-ltext ')' INTO lv_low_text.
              ELSE.
                lv_low_text = gs_auth-low.
              ENDIF.
            ELSE.
              lv_low_text = gs_auth-low.
            ENDIF.

            CONCATENATE gs_auth-field '/' lv_low_text INTO lv_field_text SEPARATED BY space.

            IF gs_auth-high IS NOT INITIAL.
              IF gs_auth-field = 'ACTVT'.
                READ TABLE gt_tactt INTO gs_tactt WITH KEY actvt = gs_auth-high BINARY SEARCH.
                IF sy-subrc = 0.
                  CONCATENATE gs_auth-high '(' gs_tactt-ltext ')' INTO lv_high_text.
                ELSE.
                  lv_high_text = gs_auth-high.
                ENDIF.
              ELSE.
                lv_high_text = gs_auth-high.
              ENDIF.
              CONCATENATE lv_field_text '-' lv_high_text INTO lv_field_text SEPARATED BY space.
            ENDIF.

            go_node = go_nodes->add_node(
              related_node = lv_role_key
              relationship = cl_gui_column_tree=>relat_last_child
              text         = lv_field_text
              data_row     = gs_output ).

            lv_field_key = go_node->get_key( ).

            CLEAR gs_node_map.
            gs_node_map-node_key  = lv_field_key.
            gs_node_map-node_type = 'Field'.
            gs_node_map-role_name = gs_auth-agr_name.
            APPEND gs_node_map TO gt_node_map.
          ENDLOOP.
        ENDLOOP.
      ENDLOOP.

      DATA(lo_settings) = go_tree->get_tree_settings( ).
      lo_settings->set_hierarchy_header( 'Hierarchy' ).
      lo_settings->set_hierarchy_size( 70 ).

      DATA(lo_columns) = go_tree->get_columns( ).
      lo_columns->set_optimize( 'X' ).

      go_tree->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
    CATCH cx_salv_not_found INTO DATA(lx_not_found).
      MESSAGE lx_not_found->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.

*======================================================================*
* PFCG Drilldown Routines (Using Standard Function Modules)
*======================================================================*
FORM open_pfcg_auth_tab USING pv_role TYPE agr_name.
  CALL FUNCTION 'PRGN_SHOW_EDIT_AGR'
    STARTING NEW TASK 'PFCG'
    EXPORTING
      agr_name      = pv_role
      mode          = 'A'
      screen        = '1'
      sicht         = '1'
    EXCEPTIONS
      agr_not_found = 3
      OTHERS        = 2.

  IF sy-subrc <> 0.
    MESSAGE 'Could not open PFCG.' TYPE 'E'.
  ENDIF.
ENDFORM.

FORM open_pfcg_display USING pv_role TYPE agr_name.
  CALL FUNCTION 'PRGN_SHOW_EDIT_AGR'
    STARTING NEW TASK 'PFCG'
    EXPORTING
      agr_name      = pv_role
      mode          = 'A'
      screen        = '1'
      sicht         = '1'
    EXCEPTIONS
      agr_not_found = 3
      OTHERS        = 2.

  IF sy-subrc <> 0.
    MESSAGE 'Could not open PFCG.' TYPE 'E'.
  ENDIF.
ENDFORM.

*FORM open_pfcg_display USING pv_role TYPE agr_name.
*  SET PARAMETER ID 'AGR' FIELD pv_role.
*  CALL TRANSACTION 'PFCG' AND SKIP FIRST SCREEN.
*ENDFORM.
*
*FORM open_pfcg_auth_tab USING pv_role TYPE agr_name.
*  SET PARAMETER ID 'AGR' FIELD pv_role.
*  " PFCG will open the role; you then manually click the Auth tab
*  CALL TRANSACTION 'PFCG'.
*ENDFORM.
