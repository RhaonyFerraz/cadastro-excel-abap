CLASS zcl_clientes_rf DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

    TYPES: BEGIN OF ty_cliente,
             linha       TYPE i,
             status      TYPE string,
             criticality TYPE i,
             cnpj        TYPE string,
             nome        TYPE string,
             endereco    TYPE string,
             cidade      TYPE string,
             uf          TYPE char2,
             cep         TYPE string,
             mensagem    TYPE string,
           END OF ty_cliente.

    TYPES tt_clientes TYPE STANDARD TABLE OF ty_cliente WITH EMPTY KEY.
    TYPES tt_pesos    TYPE STANDARD TABLE OF i WITH EMPTY KEY.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS:
      validar_cnpj
        IMPORTING iv_cnpj          TYPE string
        RETURNING VALUE(rv_valido) TYPE abap_bool.
ENDCLASS.


CLASS zcl_clientes_rf IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA lt_clientes TYPE tt_clientes.

    " 1. Carrega dados da planilha modelo Excel (casos de teste válidos e inválidos)
    lt_clientes = VALUE #(
      ( linha = 2  nome = 'Empresa Alpha Ltda'   cnpj = '11222333000181' endereco = 'Rua das Flores, 100'      cidade = 'Sao Paulo'      uf = 'SP' cep = '01310100' )
      ( linha = 3  nome = 'Beta Comercio S.A.'    cnpj = '22333444000195' endereco = 'Av. Brasil, 500'          cidade = 'Rio de Janeiro' uf = 'RJ' cep = '20040020' )
      ( linha = 4  nome = 'Gama Servicos ME'      cnpj = '33444555000106' endereco = 'Rua XV de Novembro, 200'   cidade = 'Curitiba'       uf = 'PR' cep = '80020310' )
      ( linha = 5  nome = 'Delta Industria Ltda'  cnpj = ''               endereco = 'Rua Sete de Setembro, 300' cidade = 'Belo Horizonte' uf = 'MG' cep = '30140070' )
      ( linha = 6  nome = ''                      cnpj = '55666777000148' endereco = 'Av. Paulista, 1000'       cidade = 'Sao Paulo'      uf = 'SP' cep = '01310100' )
      ( linha = 7  nome = 'Epsilon Tech S.A.'     cnpj = '12345678000100' endereco = 'Rua da Consolacao, 800'   cidade = 'Sao Paulo'      uf = 'SP' cep = '01301000' )
      ( linha = 8  nome = 'Zeta Logistica ME'     cnpj = '66777888000159' endereco = ''                         cidade = 'Recife'         uf = 'PE' cep = '50010230' )
      ( linha = 9  nome = 'Eta Consultoria Ltda'  cnpj = '00000000000000' endereco = 'Av. Getulio Vargas, 450'   cidade = 'Salvador'       uf = 'BA' cep = '40020020' )
      ( linha = 10 nome = 'Theta Agro S.A.'       cnpj = '77888999000160' endereco = 'Rod. BR-116, km 5'        cidade = 'Porto Alegre'   uf = 'RS' cep = '90010160' )
    ).

    out->write( '========================================================================' ).
    out->write( '  SAP BTP ABAP CLOUD - PROCESSAMENTO E VALIDACAO DE CLIENTES (EXCEL)    ' ).
    out->write( '========================================================================' ).
    out->write( |Total de clientes carregados da planilha: { lines( lt_clientes ) }| ).
    out->write( ' ' ).

    DATA lv_validos   TYPE i VALUE 0.
    DATA lv_invalidos TYPE i VALUE 0.

    " 2. Executa as validações linha a linha
    LOOP AT lt_clientes ASSIGNING FIELD-SYMBOL(<ls_cliente>).
      DATA(lv_erros) = ``.
      DATA(lv_ok)    = abap_true.

      " Validação 1: Nome obrigatório
      IF <ls_cliente>-nome IS INITIAL.
        lv_ok = abap_false.
        lv_erros = |{ lv_erros }[NOME vazio] |.
      ENDIF.

      " Validação 2: CNPJ obrigatório e algoritmo matemático
      IF <ls_cliente>-cnpj IS INITIAL.
        lv_ok = abap_false.
        lv_erros = |{ lv_erros }[CNPJ vazio] |.
      ELSE.
        DATA(lv_cnpj_limpo) = <ls_cliente>-cnpj.
        REPLACE ALL OCCURRENCES OF '.' IN lv_cnpj_limpo WITH ''.
        REPLACE ALL OCCURRENCES OF '/' IN lv_cnpj_limpo WITH ''.
        REPLACE ALL OCCURRENCES OF '-' IN lv_cnpj_limpo WITH ''.

        IF validar_cnpj( lv_cnpj_limpo ) = abap_false.
          lv_ok = abap_false.
          lv_erros = |{ lv_erros }[CNPJ invalido: { <ls_cliente>-cnpj }] |.
        ELSE.
          <ls_cliente>-cnpj = lv_cnpj_limpo.
        ENDIF.
      ENDIF.

      " Validação 3: Endereço obrigatório
      IF <ls_cliente>-endereco IS INITIAL.
        lv_ok = abap_false.
        lv_erros = |{ lv_erros }[ENDERECO vazio] |.
      ENDIF.

      " Atribui Status e Mensagem com Criticality para o SAP Fiori (3 = Verde, 1 = Vermelho)
      IF lv_ok = abap_true.
        <ls_cliente>-status      = 'VALIDO'.
        <ls_cliente>-criticality = 3.
        <ls_cliente>-mensagem    = 'Registro aprovado para carga'.
        lv_validos = lv_validos + 1.
      ELSE.
        <ls_cliente>-status      = 'INVALIDO'.
        <ls_cliente>-criticality = 1.
        <ls_cliente>-mensagem    = lv_erros.
        lv_invalidos = lv_invalidos + 1.
      ENDIF.
    ENDLOOP.

    " 3. Grava no banco de dados SAP HANA (Tabela ZTAB_CLIENTES_RF)
    DATA lt_db TYPE STANDARD TABLE OF ztab_clientes_rf WITH EMPTY KEY.
    lt_db = CORRESPONDING #( lt_clientes ).
    DELETE FROM ztab_clientes_rf WHERE client = @sy-mandt.
    INSERT ztab_clientes_rf FROM TABLE @lt_db.

    " 4. Exibe resultado no console
    out->write( data = lt_clientes name = 'RESULTADO DO PROCESSAMENTO' ).
    out->write( ' ' ).
    out->write( '------------------------------------------------------------------------' ).
    out->write( |RESUMO: [ Total Aprovados: { lv_validos } ] - [ Total Reprovados: { lv_invalidos } ]| ).
    out->write( 'BANCO DE DADOS: Dados gravados com sucesso na tabela ZTAB_CLIENTES_RF!' ).
    out->write( '------------------------------------------------------------------------' ).
  ENDMETHOD.


  METHOD validar_cnpj.
    rv_valido = abap_false.

    DATA(lv_len) = strlen( iv_cnpj ).
    IF lv_len <> 14.
      RETURN.
    ENDIF.

    " Rejeita sequências repetidas (ex: 00000000000000 ou 11111111111111)
    DATA(lv_primeiro) = substring( val = iv_cnpj off = 0 len = 1 ).
    DATA(lv_todos_iguais) = abap_true.
    DO 13 TIMES.
      DATA(lv_pos) = sy-index.
      IF substring( val = iv_cnpj off = lv_pos len = 1 ) <> lv_primeiro.
        lv_todos_iguais = abap_false.
        EXIT.
      ENDIF.
    ENDDO.
    IF lv_todos_iguais = abap_true.
      RETURN.
    ENDIF.

    " Pesos 1º dígito
    DATA(lt_pesos1) = VALUE tt_pesos( ( 5 ) ( 4 ) ( 3 ) ( 2 )
                                      ( 9 ) ( 8 ) ( 7 ) ( 6 )
                                      ( 5 ) ( 4 ) ( 3 ) ( 2 ) ).
    DATA(lv_soma) = 0.
    DO 12 TIMES.
      DATA(lv_idx)  = sy-index - 1.
      DATA(lv_char) = substring( val = iv_cnpj off = lv_idx len = 1 ).
      READ TABLE lt_pesos1 INTO DATA(lv_peso) INDEX sy-index.
      lv_soma = lv_soma + ( CONV i( lv_char ) * lv_peso ).
    ENDDO.

    DATA(lv_resto) = lv_soma MOD 11.
    DATA(lv_dig1)  = COND i( WHEN lv_resto < 2 THEN 0 ELSE 11 - lv_resto ).

    DATA(lv_char13) = substring( val = iv_cnpj off = 12 len = 1 ).
    IF CONV i( lv_char13 ) <> lv_dig1.
      RETURN.
    ENDIF.

    " Pesos 2º dígito
    DATA(lt_pesos2) = VALUE tt_pesos( ( 6 ) ( 5 ) ( 4 ) ( 3 ) ( 2 )
                                      ( 9 ) ( 8 ) ( 7 ) ( 6 )
                                      ( 5 ) ( 4 ) ( 3 ) ( 2 ) ).
    lv_soma = 0.
    DO 13 TIMES.
      lv_idx  = sy-index - 1.
      lv_char = substring( val = iv_cnpj off = lv_idx len = 1 ).
      READ TABLE lt_pesos2 INTO lv_peso INDEX sy-index.
      lv_soma = lv_soma + ( CONV i( lv_char ) * lv_peso ).
    ENDDO.

    lv_resto = lv_soma MOD 11.
    DATA(lv_dig2) = COND i( WHEN lv_resto < 2 THEN 0 ELSE 11 - lv_resto ).

    DATA(lv_char14) = substring( val = iv_cnpj off = 13 len = 1 ).
    IF CONV i( lv_char14 ) <> lv_dig2.
      RETURN.
    ENDIF.

    rv_valido = abap_true.
  ENDMETHOD.

ENDCLASS.
