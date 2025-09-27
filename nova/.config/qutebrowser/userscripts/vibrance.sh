#!/bin/bash

js='
(() => {
  const vid = document.querySelector("video");
  if (!vid) {
    alert("No video element found!");
    return;
  }
  const current = vid.style.filter;
  if (!current || current === "") {
    vid.style.filter = "contrast(1.1) saturate(1.2)";
    alert("Video filter: ON");
  } else {
    vid.style.filter = "";
    alert("Video filter: OFF");
  }
})();
'

qutebrowser ":jseval --quiet $js"
