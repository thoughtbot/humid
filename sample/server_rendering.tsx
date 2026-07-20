import React from "react";
import { createApp } from "@thoughtbot/superglue";
import { buildVisitAndRemote } from "./application_visit";
import { pageIdentifierToPageComponent } from "./page_to_page_mapping";
import { renderToString } from "react-dom/server";

declare function readSourceMap(filename: string): string;
declare function setHumidRenderer(
  fn: (json: string, baseUrl: string, path: string) => string,
): void;

// eslint-disable-next-line @typescript-eslint/no-require-imports
require("source-map-support").install({
  retrieveSourceMap: (filename: string) => {
    return {
      url: filename,
      map: readSourceMap(filename),
    };
  },
});

setHumidRenderer((json, baseUrl, path) => {
  const initialState = JSON.parse(json);
  const { Provider, Outlet } = createApp({
    baseUrl,
    initialPage: initialState,
    path,
    buildVisitAndRemote,
    mapping: pageIdentifierToPageComponent,
  });

  return renderToString(
    <Provider>
      <Outlet />
    </Provider>,
  );
});
