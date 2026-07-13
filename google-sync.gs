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
const SETTINGS_PATH = "settings.json";

/**
 * Reads a text file from the GitHub repository using the Contents API.
 * Returns the raw file content as a string.
 */
function readGithubFile(path) {
  const url =
    "https://api.github.com/repos/" +
    GITHUB_OWNER +
    "/" +
    GITHUB_REPO +
    "/contents/" +
    encodeURIComponent(path) +
    "?ref=" +
    encodeURIComponent(GITHUB_BRANCH);

  const options = {
    method: "get",
    headers: {
      Authorization: "Bearer " + GITHUB_TOKEN,
      // Ask GitHub to return the raw file content instead of the JSON metadata.
      Accept: "application/vnd.github.raw+json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
    muteHttpExceptions: true,
  };

  const response = UrlFetchApp.fetch(url, options);
  const status = response.getResponseCode();

  if (status !== 200) {
    console.error("Failed to read '" + path + "' from GitHub, HTTP status " + status);
    throw new Error("GitHub request failed with status " + status);
  }

  return response.getContentText();
}

/**
 * Reads and parses `settings.json` from the GitHub repository.
 * Returns an object with `calendars` and `sync` arrays.
 */
function readSettings() {
  const raw = readGithubFile(SETTINGS_PATH);
  const settings = JSON.parse(raw);

  log(`msg="settings loaded" calendars=${(settings.calendars ? settings.calendars.length : 0)} sync_jobs=${(settings.sync ? settings.sync.length : 0)}`);
  return settings;
}

function log(item) {
	console.log(item);
}