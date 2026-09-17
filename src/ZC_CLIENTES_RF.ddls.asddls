@EndUserText.label: 'Cadastro de Clientes - Fiori'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@UI.headerInfo: {
  typeName: 'Cliente',
  typeNamePlural: 'Clientes',
  title: { type: #STANDARD, value: 'nome' },
  description: { type: #STANDARD, value: 'status' }
}
define root view entity ZC_CLIENTES_RF
  as select from ztab_clientes_rf
{
      @UI.facet: [ { id: 'Cliente', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Detalhes do Cliente', position: 10 } ]

      @UI.lineItem: [ { position: 10, label: 'Linha' } ]
  key linha,

      @UI.lineItem: [ { position: 20, label: 'Status', criticality: 'criticality', criticalityRepresentation: #WITHOUT_ICON } ]
      @UI.selectionField: [ { position: 10 } ]
      status,

      criticality,

      @UI.lineItem: [ { position: 30, label: 'CNPJ' } ]
      @UI.selectionField: [ { position: 20 } ]
      cnpj,

      @UI.lineItem: [ { position: 40, label: 'Nome / Razao Social' } ]
      nome,

      @UI.lineItem: [ { position: 50, label: 'Endereco' } ]
      endereco,

      @UI.lineItem: [ { position: 60, label: 'Cidade' } ]
      cidade,

      @UI.lineItem: [ { position: 70, label: 'UF' } ]
      uf,

      @UI.lineItem: [ { position: 80, label: 'CEP' } ]
      cep,

      @UI.lineItem: [ { position: 90, label: 'Mensagem de Validacao' } ]
      mensagem
}
