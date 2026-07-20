// Notification history section for the Quick Settings panel, plus the shared
// notification card used by both the panel and the transient popups.
// Backed by AstalNotifd, which this process runs as the notification daemon.
import { bind } from "astal";
import { Gtk } from "astal/gtk3";
import Notifd from "gi://AstalNotifd";

const notifd = Notifd.get_default();

function urgency(n: Notifd.Notification): string {
  switch (n.urgency) {
    case Notifd.Urgency.CRITICAL:
      return "critical";
    case Notifd.Urgency.LOW:
      return "low";
    default:
      return "normal";
  }
}

function time(ms: number): string {
  return GLib_format(ms);
}

// Small helper so we don't pull in a date lib; falls back gracefully.
function GLib_format(unixSeconds: number): string {
  try {
    const d = new Date(unixSeconds * 1000);
    return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  } catch {
    return "";
  }
}

export function NotificationCard(n: Notifd.Notification) {
  return (
    <box className={`notification-card ${urgency(n)}`} vertical>
      <box className="notif-header">
        {n.appIcon || n.desktopEntry ? (
          <icon className="notif-app-icon" icon={n.appIcon || n.desktopEntry} />
        ) : (
          <box />
        )}
        <label
          className="notif-app-name"
          label={n.appName || "Notification"}
          xalign={0}
          hexpand
        />
        <label className="notif-time" label={time(n.time)} />
        <button className="notif-close" onClicked={() => n.dismiss()}>
          <label label={"\u{f0156}"} />
        </button>
      </box>
      <box className="notif-body" vertical>
        <label
          className="notif-summary"
          label={n.summary}
          xalign={0}
          wrap
          maxWidthChars={34}
        />
        {n.body ? (
          <label
            className="notif-text"
            label={n.body}
            xalign={0}
            wrap
            useMarkup
            maxWidthChars={34}
          />
        ) : (
          <box />
        )}
      </box>
      {n.get_actions().length > 0 && (
        <box className="notif-actions" homogeneous>
          {n.get_actions().map((a) => (
            <button className="notif-action" onClicked={() => n.invoke(a.id)}>
              <label label={a.label} />
            </button>
          ))}
        </box>
      )}
    </box>
  );
}

export default function NotificationSection() {
  return (
    <box className="qs-section notifications" vertical>
      <box className="qs-section-header">
        <label
          className="qs-section-title"
          label="Notifications"
          xalign={0}
          hexpand
        />
        <button
          className="qs-dnd-toggle"
          tooltipText="Do not disturb"
          onClicked={() => (notifd.dontDisturb = !notifd.dontDisturb)}
        >
          <label
            label={bind(notifd, "dontDisturb").as((d) =>
              d ? "\u{f009b}" : "\u{f009a}",
            )}
          />
        </button>
        <button
          className="qs-clear-all"
          tooltipText="Clear all"
          onClicked={() => notifd.notifications.forEach((n) => n.dismiss())}
        >
          <label label={"\u{f00e2}"} />
        </button>
      </box>
      <scrollable
        className="notif-history"
        heightRequest={220}
        vscroll={Gtk.PolicyType.AUTOMATIC}
        hscroll={Gtk.PolicyType.NEVER}
      >
        <box vertical>
          {bind(notifd, "notifications").as((list) =>
            list.length === 0
              ? [<label className="notif-empty" label="No notifications" />]
              : list.map(NotificationCard),
          )}
        </box>
      </scrollable>
    </box>
  );
}
