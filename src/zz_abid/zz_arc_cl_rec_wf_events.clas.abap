class ZZ_ARC_CL_REC_WF_EVENTS definition
  public
  final
  create public .

public section.

  interfaces IF_BADI_INTERFACE .
  interfaces BI_OBJECT .
  interfaces BI_PERSISTENT .
  interfaces IF_WORKFLOW .

  data LV_AGR_NAME type AGR_NAME_C .
  data LV_CHILD_AGR type CHILD_AGR .

  events START
    exporting
      value(EMAIL_ADDR) type CHAR30 .

  methods CONSTRUCTOR
    importing
      !LV_AGR_NAME type AGR_NAME_C .
  class-methods GET_EMAIL_ADRESSES
    importing
      !IT_USERS type ZRECMAN_MAIL optional
    exporting
      !ET_EMAILADDRESS type ZRECMAN_MAIL .
  class-methods TRIGGER_EVENT
    importing
      !IV_OBJECT_KEY type CHAR30 .
protected section.
private section.

  types:
    BEGIN OF ty_s_inst_buffer,
      agr_name TYPE agr_name_c, " Composite role
      instance TYPE REF TO object, " class
    END OF ty_s_inst_buffer .
  types:
    ty_t_inst_buffer TYPE STANDARD TABLE OF ty_s_inst_buffer WITH KEY agr_name .

  data MS_LPOR type SIBFLPOR .
  class-data MT_INSTANCE_BUFFER type TY_T_INST_BUFFER .
ENDCLASS.



CLASS ZZ_ARC_CL_REC_WF_EVENTS IMPLEMENTATION.


  method CONSTRUCTOR.
    DO .

    ENDDO.
  endmethod.


  METHOD get_email_adresses.
*    SELECT * FROM usr21 INTO TABLE @DATA(lt_usr21)
*      WHERE bname = .
  ENDMETHOD.


  METHOD trigger_event.
    DATA: lv_object_type     TYPE  char30,
          lv_object_key      TYPE  swr_struct-object_key,
          lv_event           TYPE  swr_struct-event,
          lv_ret_code        TYPE  sy-subrc,
          lv_event_id        TYPE  swr_struct-event_id,
          lv_container       TYPE REF TO if_swf_cnt_container,
          lv_event_container TYPE REF TO if_swf_ifs_parameter_container,
          lo_event           TYPE REF TO if_swf_evt_event.
    DATA: lt_email_addr TYPE TABLE OF ZRECMAN_MAIL.
    DATA: ls_email_addr TYPE ZRECMAN_MAIL.
    DATA: lv_email_addr TYPE char30.

    lv_object_type = 'ZZ_ARC_CL_REC_WF_EVENTS'.
    lv_object_key  =  iv_object_key.
    lv_event       = 'START'.

    TRY.
        CALL METHOD cl_swf_cnt_factory=>create_event_container
          EXPORTING
            im_objcateg = 'CL'             " Type of Object Type: 'BO' = BOR, 'CL' = ABAP Objects
            im_objtype  = lv_object_type                 " Object Type/Class
            im_event    = lv_event                 " Event Name
*           im_persistence_classname = space            " Name of Persistence Class
          RECEIVING
            re_instance = lv_container.                 " Container - Implementation of a 'Collection'
      CATCH cx_swf_utl_obj_create_failed. " Exception When Creating an Object
*          RAISE EXCEPTION TYPE cx_bo_error.
    ENDTRY.

    lv_event_container ?= lv_container.
    TRY.
*        ls_email_addr-email = 'test@gmail.com'.
*        APPEND ls_email_addr TO lt_email_addr.
*        CLEAR ls_email_addr.
*
*        ls_email_addr-email = 'test1@gmail.com'.
*        APPEND ls_email_addr TO lt_email_addr.
*        CLEAR ls_email_addr.
lv_email_addr = 'test@gmail.com'.
        CALL METHOD lv_event_container->set
          EXPORTING
            name  = 'EMAIL_ADDR'         " Name of Parameter Whose Value Is to Be Set
            value = lv_email_addr            " Value
*           unit  =                  " Unit
*            IMPORTING
*           returncode =                  " Errors Occurred (If Asked -> No RAISE)
          .
      CATCH cx_swf_cnt_cont_access_denied. " Changed Access Not Allowed
      CATCH cx_swf_cnt_elem_access_denied. " Value/Unit Must Not Be Changed
      CATCH cx_swf_cnt_elem_not_found.     " Element Not in the Container
      CATCH cx_swf_cnt_elem_type_conflict. " Type Conflict Between Value and Current Parameter
      CATCH cx_swf_cnt_unit_type_conflict. " Type Conflict Between Unit and Current Parameter
      CATCH cx_swf_cnt_elem_def_invalid.   " Element Definition Is Invalid (Internal Error)
      CATCH cx_swf_cnt_container.          " Exception in the Container Service
    ENDTRY.


    CALL METHOD cl_swf_evt_event=>get_instance
      EXPORTING
        im_objcateg        = 'CL'                     " Workflow: Object Type BO, CL ...
        im_objtype         = lv_object_type           " Class
        im_event           = lv_event                 " Event Name
        im_objkey          = iv_object_key            " Object Key
        im_event_container = lv_event_container       " Event Parameter
      RECEIVING
        re_event           = lo_event.                " Event

    CALL METHOD lo_event->set_property
      EXPORTING
        im_property = if_swf_evt_event=>mc_prop_sync_no_commit                  " Property of Event
        im_value    = abap_true.            " Value of Property
    TRY.
        CALL METHOD lo_event->raise.
      CATCH cx_swf_evt_invalid_objtype. " Error in Class / Object Type
      CATCH cx_swf_evt_invalid_event.   " Error in Event.
    ENDTRY.


  ENDMETHOD.
ENDCLASS.
