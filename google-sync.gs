/**
 * calsyn - Google AppScript
 *
 * Synchronizes a Google Calendar with other calendars through a private
 * GitHub repository. See README.md for the full architecture.
 *
 */

// Script configuraiton
// Add these values as system properties (App Script -> Project Settings → Script Properties),
// or set a default value
const GITHUB_OWNER = PropertiesService.getScriptProperties().getProperty("GITHUB_OWNER") || "";
const GITHUB_REPO = PropertiesService.getScriptProperties().getProperty("GITHUB_REPO") || "";
const GITHUB_BRANCH = PropertiesService.getScriptProperties().getProperty("GITHUB_BRANCH") || "";
const GITHUB_TOKEN = PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN") || "";
const PROFILE = PropertiesService.getScriptProperties().getProperty("PROFILE") || "";
const SETTINGS_PATH = "settings.json";
const SYNC_WINDOW_DAYS = 14;

/**
 * Entry point, to be run every 5 minutes by a time-driven trigger.
 * 1. Exports the calendar events to `<PROFILE>-events.json`
 * 2. Syncs the clone events for every job where this calendar is a destination
 */
function main() {
  const settings = readSettings();
  exportEvents(settings);
  syncDestinations(settings);
}

/**
 * Returns the [start, end] Date pair of the sync window:
 * from today at 00:00 to now + SYNC_WINDOW_DAYS days.
 */
function syncWindow() {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const end = new Date(Date.now() + SYNC_WINDOW_DAYS * 24 * 60 * 60 * 1000);
  return [start, end];
}

/**
 * Overwrites `<PROFILE>-events.json` in the GitHub repository with all the
 * events of this calendar in the sync window, excluding the events whose
 * title starts with any of the `event_clone_prefix` defined in settings.json.
 */
function exportEvents(settings) {
  const prefixes = settings.calendars.map((c) => c.event_clone_prefix).filter((p) => p);
  const [start, end] = syncWindow();
  const calendar = CalendarApp.getCalendarById(PROFILE);

  const events = calendar
    .getEvents(start, end)
    .filter((e) => !prefixes.some((p) => e.getTitle().startsWith(p)))
    .map((e) => ({
      title: normalize(e.getTitle()),
      from: formatDateUTC(e.getStartTime()),
      to: formatDateUTC(e.getEndTime()),
      description: normalize(e.getDescription()),
    }));

  writeGithubFile(`${PROFILE}-events.json`, JSON.stringify(events, null, 2));
  log(`msg="events exported" profile=${PROFILE} count=${events.length}`);
}

/**
 * For every sync job where this calendar is a destination, reconciles the
 * clone events against the `<source.profile>-events.json` files:
 * clones whose hash is no longer in the source file are deleted, missing
 * ones are created, matching ones are left untouched.
 */
function syncDestinations(settings) {
  const me = settings.calendars.find((c) => c.profile === PROFILE);
  if (!me) {
    console.error(`msg="calendar not found in settings" profile=${PROFILE}`);
    throw new Error(`Calendar with profile '${PROFILE}' not found in settings.json`);
  }

  const calendar = CalendarApp.getCalendarById(PROFILE);
  const [start, end] = syncWindow();

  const jobs = settings.sync.filter((j) => j.destinations.includes(me.name));
  for (const job of jobs) {
    for (const sourceName of job.sources) {
      const source = settings.calendars.find((c) => c.name === sourceName);
      if (!source) {
        console.error(`msg="source calendar not found in settings" job="${job.job}" source=${sourceName}`);
        continue;
      }
      syncSource(calendar, job, source, start, end);
    }
  }
}

/**
 * Reconciles the clones of a single source into the destination calendar.
 * The wanted state is the list of events in `<source.profile>-events.json`,
 * reduced to the fields listed in `job.details` and identified by their hash.
 * Existing clones (events with the source prefix in the sync window) that
 * match a wanted hash are kept, the others are deleted; wanted events left
 * unmatched are created.
 */
function syncSource(calendar, job, source, start, end) {
  const prefix = source.event_clone_prefix;
  const details = job.details || [];
  const raw = readGithubFile(`${source.profile}-events.json`);
  if (raw === null) {
    log(`msg="source events file not found, skipping" job="${job.job}" source=${source.name}`);
    return;
  }

  // Wanted clones: source events inside the window, reduced to the cloned fields
  const wanted = JSON.parse(raw)
    .filter((e) => {
      const eventStart = parseDateUTC(e.from);
      return eventStart >= start && eventStart <= end;
    })
    .map((e) => {
      const title = details.includes("title") ? normalize(e.title) : "";
      const description = details.includes("description") ? normalize(e.description) : "";
      return { title: title, from: e.from, to: e.to, description: description };
    });
  const wantedHashes = wanted.map((e) => computeHash(e.title, e.from, e.to, e.description));

  // Existing clones: events in the window whose title starts with the source prefix.
  // Every clone matching a wanted hash consumes it (multiset semantics, so
  // duplicated events are preserved); clones without a match are deleted.
  const clones = calendar.getEvents(start, end).filter((e) => e.getTitle().startsWith(prefix));
  let deleted = 0;
  for (const clone of clones) {
    const title = normalize(clone.getTitle().slice(prefix.length));
    const hash = computeHash(
      title,
      formatDateUTC(clone.getStartTime()),
      formatDateUTC(clone.getEndTime()),
      normalize(clone.getDescription())
    );

    const index = wantedHashes.indexOf(hash);
    if (index >= 0) {
      wantedHashes.splice(index, 1);
      wanted.splice(index, 1);
    } else {
      clone.deleteEvent();
      deleted += 1;
    }
  }

  for (const event of wanted) {
    const title = event.title ? `${prefix} ${event.title}` : prefix;
    calendar.createEvent(title, parseDateUTC(event.from), parseDateUTC(event.to), {
      description: event.description,
    });
  }

  log(`msg="source synced" job="${job.job}" source=${source.name} created=${wanted.length} deleted=${deleted} kept=${clones.length - deleted}`);
}

/**
 * Returns the sha1 identity of a clone, computed only on the cloned fields.
 * See README.md -> "Hash".
 */
function computeHash(title, fromStr, toStr, description) {
  const payload = `${title}|${fromStr}|${toStr}|${description}`;
  const digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_1, payload, Utilities.Charset.UTF_8);
  return digest.map((b) => ((b + 256) % 256).toString(16).padStart(2, "0")).join("");
}

// Normalizes a string before hashing: null-safe, trimmed, unix line endings
function normalize(value) {
  return (value || "").replace(/\r\n/g, "\n").trim();
}

// Formats a Date as `YYYY-MM-DD HH:MM` in UTC
function formatDateUTC(date) {
  return Utilities.formatDate(date, "UTC", "yyyy-MM-dd HH:mm");
}

// Parses a `YYYY-MM-DD HH:MM` UTC string into a Date
function parseDateUTC(value) {
  return new Date(`${value.replace(" ", "T")}:00Z`);
}

/**
 * Reads a text file from the GitHub repository using the Contents API.
 * Returns the raw file content as a string, or null if the file does not exist.
 */
function readGithubFile(path) {
  const url = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/contents/${encodeURIComponent(path)}?ref=${encodeURIComponent(GITHUB_BRANCH)}`;
  const options = {
    method: "get",
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      // Ask GitHub to return the raw file content instead of the JSON metadata.
      Accept: "application/vnd.github.raw+json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
    muteHttpExceptions: true,
  };

  const response = UrlFetchApp.fetch(url, options);
  const status = response.getResponseCode();

  if (status === 404) {
    return null;
  }

  if (status !== 200) {
    console.error(`msg="github read failed" path=${path} status=${status}`);
    throw new Error(`GitHub request failed with status ${status}`);
  }

  return response.getContentText();
}

/**
 * Creates or updates a file in the GitHub repository using the Contents API.
 * The update is skipped when the remote content is already identical, to
 * avoid a commit every run.
 */
function writeGithubFile(path, content) {
  const url = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/contents/${encodeURIComponent(path)}`;
  const headers = {
    Authorization: `Bearer ${GITHUB_TOKEN}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
  };

  // Fetch the current file metadata to get its sha (required to update)
  // and skip the write if the content did not change
  const getResponse = UrlFetchApp.fetch(`${url}?ref=${encodeURIComponent(GITHUB_BRANCH)}`, {
    method: "get",
    headers: headers,
    muteHttpExceptions: true,
  });

  let sha = null;
  if (getResponse.getResponseCode() === 200) {
    const current = JSON.parse(getResponse.getContentText());
    sha = current.sha;
    const currentContent = Utilities.newBlob(Utilities.base64Decode(current.content)).getDataAsString();
    if (currentContent === content) {
      log(`msg="file unchanged, skipping write" path=${path}`);
      return;
    }
  }

  const payload = {
    message: `calsyn: update ${path}`,
    content: Utilities.base64Encode(content, Utilities.Charset.UTF_8),
    branch: GITHUB_BRANCH,
  };
  if (sha) {
    payload.sha = sha;
  }

  const putResponse = UrlFetchApp.fetch(url, {
    method: "put",
    headers: headers,
    contentType: "application/json",
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  });

  const status = putResponse.getResponseCode();
  if (status !== 200 && status !== 201) {
    console.error(`msg="github write failed" path=${path} status=${status} body=${putResponse.getContentText()}`);
    throw new Error(`GitHub write failed with status ${status}`);
  }

  log(`msg="file written" path=${path} status=${status}`);
}

/**
 * Reads and parses `settings.json` from the GitHub repository.
 * Returns an object with `calendars` and `sync` arrays.
 */
function readSettings() {
  const raw = readGithubFile(SETTINGS_PATH);
  if (raw === null) {
    console.error(`msg="settings.json not found in the repository"`);
    throw new Error("settings.json not found in the repository");
  }

  const settings = JSON.parse(raw);
  log(`msg="settings loaded" calendars=${(settings.calendars ? settings.calendars.length : 0)} sync_jobs=${(settings.sync ? settings.sync.length : 0)}`);
  return settings;
}

function log(item) {
	console.log(item);
}
