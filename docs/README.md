# 📋 Cadastro de Clientes via Excel — ABAP

Projeto didático de ABAP que lê uma planilha Excel com dados de clientes,
valida os campos e exibe o resultado em um ALV Grid.

---

## 🗂️ Estrutura do Projeto

```
cadastro-excel-abap/
├── src/
│   ├── ZCLIENTES_EXCEL.prog.abap        ← Programa principal (REPORT)
│   ├── ZCLIENTES_EXCEL_TOP.prog.abap    ← Include: declarações globais
│   ├── ZCLIENTES_EXCEL_SEL.prog.abap    ← Include: tela de seleção
│   └── ZCLIENTES_EXCEL_SUB.prog.abap    ← Include: subrotinas (FORMs)
├── excel/
│   ├── modelo_clientes.xlsx             ← Planilha pronta e estilizada (recomendada)
│   └── modelo_clientes.csv              ← Modelo alternativo em CSV (UTF-8 com BOM)
└── docs/
    └── README.md                        ← Este arquivo
```

---

## 🚀 Como Usar

### 1. Criar os objetos no SAP

1. Acesse a **SE38** (Editor ABAP)
2. Crie o programa `ZCLIENTES_EXCEL` do tipo **Executable Program**
3. Crie os 3 includes com os respectivos nomes
4. Copie o conteúdo de cada arquivo `.abap` do projeto

### 2. Acessar a planilha modelo

Utilize o arquivo pronto `excel/modelo_clientes.xlsx`, que já possui:
- Cabeçalhos formatados em azul corporativo SAP (`#1F4E79`) com texto em branco e negrito
- Colunas com larguras pré-ajustadas
- Linhas zebradas para facilitar a leitura
- Campos **CNPJ** e **CEP** configurados como Texto (preserva zeros à esquerda)
- Acentos corretos em UTF-8

| Coluna A | Coluna B | Coluna C | Coluna D | Coluna E | Coluna F |
|----------|----------|----------|----------|----------|----------|
| NOME     | CNPJ     | ENDEREÇO | CIDADE   | UF       | CEP      |

### 3. Executar

1. Execute o programa `ZCLIENTES_EXCEL` via **SE38** ou **SA38**
2. Na tela de seleção, clique no **ícone de lupa** ao lado do campo Arquivo
3. Selecione o arquivo `.xlsx`
4. Pressione **F8** (Execute)

---

## 📚 Conceitos ABAP Aprendidos

### 1. Leitura de Arquivo Excel — `ALSM_EXCEL_TO_INTERNAL_TABLE`

```abap
CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
  EXPORTING
    filename    = gv_filepath
    i_begin_col = 1
    i_begin_row = 1
    i_end_col   = 6
    i_end_row   = 9999
  TABLES
    intern      = gt_excel.
```

- RFC padrão SAP que converte células do Excel em tabela interna
- Cada célula vira uma linha com `ROW`, `COL` e `VALUE`
- Linha 1 = cabeçalho → ignorada no mapeamento

---

### 2. Diálogo de Browse de Arquivo — `CL_GUI_FRONTEND_SERVICES`

```abap
CALL METHOD cl_gui_frontend_services=>file_open_dialog
  EXPORTING
    window_title      = 'Selecionar Planilha'
    default_extension = 'xlsx'
    file_filter       = 'Arquivos Excel (*.xlsx)|*.xlsx|'
  CHANGING
    file_table        = lt_filetable
    rc                = lv_rc
    user_action       = lv_action.
```

- Abre o diálogo nativo do Windows no lado do **presentation server**
- O evento `AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file` ativa a lupa (F4)

---

### 3. Mapeamento de Colunas

```abap
CASE ls_excel-col.
  WHEN 1. gs_cliente-nome     = ls_excel-value.
  WHEN 2. gs_cliente-cnpj     = ls_excel-value.
  WHEN 3. gs_cliente-endereco = ls_excel-value.
  WHEN 4. gs_cliente-cidade   = ls_excel-value.
  WHEN 5. gs_cliente-uf       = ls_excel-value.
  WHEN 6. gs_cliente-cep      = ls_excel-value.
ENDCASE.
```

- O CASE mapeia o número da coluna para o campo da estrutura
- Detecta nova linha comparando `ls_excel-row <> lv_linha`

---

### 4. Validações de Campos

```abap
" Campo obrigatório
IF gs_cliente-nome IS INITIAL.
  lv_valido = abap_false.
  lv_erros = |{ lv_erros }[NOME vazio] |.
ENDIF.
```

- Usa **template literals** com `| |` para concatenar mensagens
- Acumula todos os erros da linha em uma única string

---

### 5. Algoritmo de Validação de CNPJ

O CNPJ possui 14 dígitos: 12 de identificação + 2 verificadores.

```
CNPJ:  1  1  2  2  2  3  3  3  0  0  0  1  8  1
       |  |  |  |  |  |  |  |  |  |  |  |  |  |
Peso:  5  4  3  2  9  8  7  6  5  4  3  2  D1 D2
```

**Cálculo do 1º dígito:**
1. Multiplica os 12 primeiros dígitos pelos pesos 5,4,3,2,9,8,7,6,5,4,3,2
2. Soma todos os produtos
3. `resto = soma MOD 11`
4. Se `resto < 2` → dígito = 0; senão → dígito = `11 - resto`

**Cálculo do 2º dígito:**
- Repete com 13 dígitos e pesos 6,5,4,3,2,9,8,7,6,5,4,3,2

---

### 6. ALV Grid com `CL_SALV_TABLE`

```abap
" Cria o objeto ALV
cl_salv_table=>factory(
  IMPORTING r_salv_table = go_alv
  CHANGING  t_table      = gt_clientes ).

" Ativa toolbar completa
go_alv->get_functions( )->set_all( abap_true ).

" Configura textos das colunas
go_column->set_short_text(  'St.' ).
go_column->set_medium_text( 'Status' ).
go_column->set_long_text(   'Status de Validação' ).

" Exibe
go_alv->display( ).
```

- `CL_SALV_TABLE` é a abordagem **OO moderna** (preferida ao `REUSE_ALV_*`)
- `set_all( abap_true )` ativa exportar Excel, ordenar, filtrar
- A coluna `STATUS` com `ICON_D` exibe automaticamente os LEDs coloridos

---

## Dados de Teste — Erros Intencionais no Modelo

| Linha | Situação Esperada |
|-------|-------------------|
| 2     | Válido |
| 3     | Válido |
| 4     | Válido |
| 5     | CNPJ vazio |
| 6     | Nome vazio |
| 7     | CNPJ inválido (dígitos verificadores errados) |
| 8     | Endereço vazio |
| 9     | CNPJ inválido (todos zeros) |
| 10    | Válido |

---

## Ajustes Necessários no Sistema SAP

| Item | O que ajustar |
|------|---------------|
| `MESSAGE-ID zz` | Troque por uma message class existente no seu sistema |
| Autorização | O RFC `ALSM_EXCEL_TO_INTERNAL_TABLE` requer RFC_CALL |
| Versão SAP | Testado em ECC 6.0+ e S/4HANA 1909+ |

---

## Próximos Passos Sugeridos

- **Exercício 1**: Adicionar validação de CEP (8 dígitos numéricos)
- **Exercício 2**: Persistir os registros válidos na tabela customizada `ZCLIENTES`
- **Exercício 3**: Adicionar um botão customizado na toolbar do ALV para salvar
- **Próximo Módulo**: Cadastro com persistência em banco de dados (INSERT/UPDATE com `COMMIT WORK`)
