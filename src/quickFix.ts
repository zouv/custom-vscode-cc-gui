// [CUSTOM-BEGIN] CUSTOM-20261009-003 - 全局命名空间重命名 ccGui.* → ccgc.*：本文件内的命令 id / 视图 id / 配置键 / 上下文键 / 输出通道名已改名，好与上游 vscode-cc-gui 同时安装不再冲突。
// 上游合并后若本文件出现新的 ccGui.* 引用，需按 registry.md 的命名空间映射重新应用。
// [CUSTOM-END] CUSTOM-20261009-003
import * as vscode from 'vscode';
import { BridgeServer } from './bridge';

export interface QuickFixCommandArgs {
  uri: vscode.Uri;
  diagnostic: vscode.Diagnostic;
}

export class ClaudeQuickFixProvider implements vscode.CodeActionProvider {
  constructor(private readonly bridge: BridgeServer) {}

  provideCodeActions(
    document: vscode.TextDocument,
    range: vscode.Range,
    context: vscode.CodeActionContext
  ): vscode.CodeAction[] {
    if (context.diagnostics.length === 0) return [];

    return context.diagnostics.map(diag => {
      const action = new vscode.CodeAction(
        `Fix with CC GUI: ${diag.message.slice(0, 60)}${diag.message.length > 60 ? '...' : ''}`,
        vscode.CodeActionKind.QuickFix
      );
      action.command = {
        command: 'ccgc.quickFixWithClaude',
        title: 'Fix with CC GUI',
        arguments: [{ uri: document.uri, diagnostic: diag } satisfies QuickFixCommandArgs],
      };
      action.diagnostics = [diag];
      return action;
    });
  }
}
