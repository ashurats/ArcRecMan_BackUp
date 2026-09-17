FUNCTION Y_CHANGE_USER_PASSWORD.
****"----------------------------------------------------------------------
****"*"Local Interface:
****"  IMPORTING
****"     REFERENCE(USUARIO)
****"----------------------------------------------------------------------
***
***  TYPE-POOLS: abap.
***
***  DATA:
***     w_pwd_reset   TYPE bapipwd    ,
***     w_pwd_x       TYPE bapipwdx   ,
***     w_retorno     TYPE bapiret2   ,
***     v_usr_existe  TYPE i          ,
***     v_usuario     TYPE string     ,
***     v_senha_reset TYPE rsyst-bcode,
***     v_usr_sap     TYPE sy-uname   ,
***     v_nova_senha  TYPE rsyst-bcode,
***     w_return      TYPE bapiret2   .
***
***  v_usuario           = usuario          .
***  w_pwd_reset-bapipwd = 'Mudar@123$reset'.                  "#EC NOTEXT
***
**** Remove espaço no nome do usuário e senha
***  CONDENSE v_usuario NO-GAPS.
***
**** Dados de logon (utilização parte do núcleo)
***  SELECT COUNT( DISTINCT bname )
***   FROM usr02
***   INTO v_usr_existe
***   WHERE bname = usuario.
***
**** Retorna erro se o usuário não existir
***  IF v_usr_existe = 0.
***    w_retorno-type    = 'W'                           .     "#EC NOTEXT
***    w_retorno-message = 'Usuário & não existe no SAP' .     "#EC NOTEXT
***    REPLACE '&' WITH v_usuario INTO w_retorno-message .
***    APPEND w_retorno TO t_retorno                     .
***
***  ELSE.
***
****   Verifica se é para desbloquear o usuário
***    IF desbloqueia IS NOT INITIAL.
****     Desbloqueia o usuário
***      CALL FUNCTION 'BAPI_USER_UNLOCK'
***        EXPORTING
***          username = usuario
***        TABLES
***          return   = t_retorno.
***
***      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
***    ENDIF.
***
****   Retorna erro se a senha não tiver sido informada
***    IF senha IS INITIAL.
***      w_retorno-type    = 'E'                                        . "#EC NOTEXT
***      w_retorno-message = 'Senha não foi informada para o usuário & '. "#EC NOTEXT
***      REPLACE '&' WITH v_usuario INTO w_retorno-message              .
***      APPEND w_retorno TO t_retorno                                  .
***    ELSE.
***
****     Reseta a senha do usuário
***      w_pwd_x-bapipwd = abap_true.
***
***      CALL FUNCTION 'BAPI_USER_CHANGE'
***        EXPORTING
***          username  = usuario
***          password  = w_pwd_reset
***          passwordx = w_pwd_x
***        TABLES
***          return    = t_retorno.
***
***      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
***
***      v_usr_sap     = usuario            .
***      v_senha_reset = w_pwd_reset-bapipwd.
***      v_nova_senha  = senha              .
***
****     Altera a senha do usuário com a nova informada na RFC
***      CALL FUNCTION 'SUSR_USER_CHANGE_PASSWORD_RFC'
***        EXPORTING
***          bname                     = v_usr_sap
***          password                  = v_senha_reset
***          new_password              = v_nova_senha
***        IMPORTING
***          return                    = w_return
***        EXCEPTIONS
***          change_not_allowed        = 1
***          password_not_allowed      = 2
***          internal_error            = 3
***          canceled_by_user          = 4
***          password_attempts_limited = 5
***          OTHERS                    = 6.
***
***      IF sy-subrc <> 0.
***        w_retorno-type    = 'E'                          .  "#EC NOTEXT
***        w_retorno-message = w_return-message             .  "#EC NOTEXT
***        REPLACE '&' WITH v_usuario INTO w_retorno-message.
***        APPEND w_retorno TO t_retorno                    .
***      ENDIF.
***    ENDIF.
***  ENDIF.






ENDFUNCTION.
