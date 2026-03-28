unit OrderAPI.Database;

{***************************************************************************}
{  Order API - Database Context                                             }
{  Seguindo o padrão do Web.Dext.Starter.Admin                              }
{***************************************************************************}

interface

uses
  System.SysUtils,
  Dext.Entity;

type
  /// <summary>
  ///   Database context para o Order API.
  ///   O pooling é configurado no Startup via AddDbContext.
  /// </summary>
  {$M+}
  TOrderDbContext = class(TDbContext)
  end;

implementation

end.
