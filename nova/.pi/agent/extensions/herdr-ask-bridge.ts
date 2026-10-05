// Forwards rpiv-ask-user-question's blocked event to herdr's pi integration (pane turns red while a question waits).
export default function (pi) {
  pi.events.on("rpiv:ask-user:blocked", (data) => {
    pi.events.emit("herdr:blocked", data?.active ? { active: true, label: "Waiting for answer" } : { active: false });
  });
}
