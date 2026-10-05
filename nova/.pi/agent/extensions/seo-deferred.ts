// Loads pi-seo with its tools deferred: not declared to the model, no status line.
// Reach via codemode: searchTools("seo") / tools.seo_lighthouse_report({...}).
// pi-seo's own auto-load is disabled in settings.json (packages filter extensions: []).
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import seo from "../npm/node_modules/pi-seo/extensions/index.ts";

export default function (pi: ExtensionAPI) {
  const proxy = new Proxy(pi, {
    get(target, prop, receiver) {
      if (prop === "registerTool")
        return (tool: any) => {
          const { promptSnippet, promptGuidelines, ...rest } = tool;
          return target.registerTool({ ...rest, exposure: "deferred" });
        };
      if (prop === "on")
        return (event: string, handler: any) =>
          event === "session_start" ? undefined : target.on(event as any, handler);
      const v = Reflect.get(target, prop, receiver);
      return typeof v === "function" ? v.bind(target) : v;
    },
  });
  seo(proxy);
}
