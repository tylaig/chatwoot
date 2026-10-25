import {
  format,
  isSameYear,
  isThisYear,
  isToday,
  isYesterday,
  fromUnixTime,
  formatDistanceToNow,
  differenceInDays,
} from 'date-fns';
import { ptBR } from 'date-fns/locale';

const getActiveDateFnsLocale = () => {
  const htmlLang =
    typeof document !== 'undefined' ? document.documentElement?.lang || '' : '';
  const selectedLocale =
    window?.chatwootConfig?.selectedLocale || htmlLang || 'pt_BR';
  if (String(selectedLocale).toLowerCase().startsWith('pt')) {
    return ptBR;
  }
  return undefined;
};

/**
 * Formats a Unix timestamp into a human-readable time format.
 * @param {number} time - Unix timestamp.
 * @param {string} [dateFormat='h:mm a'] - Desired format of the time.
 * @returns {string} Formatted time string.
 */
export const messageStamp = (time, dateFormat = 'h:mm a') => {
  const unixTime = fromUnixTime(time);
  const locale = getActiveDateFnsLocale();
  if (locale && dateFormat === 'h:mm a') {
    return format(unixTime, 'HH:mm', { locale });
  }
  return format(unixTime, dateFormat, ...(locale ? [{ locale }] : []));
};

/**
 * Provides a formatted timestamp, adjusting the format based on the current year.
 * @param {number} time - Unix timestamp.
 * @param {string} [dateFormat='MMM d, yyyy'] - Desired date format.
 * @returns {string} Formatted date string.
 */
export const messageTimestamp = (time, dateFormat = 'MMM d, yyyy') => {
  const messageTime = fromUnixTime(time);
  const now = new Date();
  const locale = getActiveDateFnsLocale();
  if (locale && dateFormat === 'LLL d, h:mm a') {
    return format(messageTime, 'HH:mm', { locale });
  }
  const messageDate = format(
    messageTime,
    dateFormat,
    ...(locale ? [{ locale }] : [])
  );
  if (!isSameYear(messageTime, now)) {
    return format(
      messageTime,
      'LLL d y, h:mm a',
      ...(locale ? [{ locale }] : [])
    );
  }
  return messageDate;
};

/**
 * Formats a Unix timestamp into a localized date divider label (e.g., "Hoje, 22 de Outubro").
 * @param {number} time - Unix timestamp.
 * @returns {string} Formatted date divider label.
 */
export const formatMessageDateDivider = time => {
  if (!time) return '';
  const date = fromUnixTime(time);
  const locale = getActiveDateFnsLocale() || ptBR;
  const day = format(date, 'd', { locale });
  const rawMonth = format(date, 'MMMM', { locale });
  const month = rawMonth.charAt(0).toUpperCase() + rawMonth.slice(1);
  const dayAndMonth = `${day} de ${month}`;

  if (isToday(date)) return `Hoje, ${dayAndMonth}`;
  if (isYesterday(date)) return `Ontem, ${dayAndMonth}`;
  if (isSameYear(date, new Date())) return dayAndMonth;
  return `${dayAndMonth} de ${format(date, 'yyyy', { locale })}`;
};

/**
 * Formats a Unix timestamp relative to today: the time for today, a caller-
 * supplied label for yesterday, and a date otherwise. The yesterday label is
 * passed in so the caller keeps ownership of translation.
 * @param {number} time - Unix timestamp.
 * @param {string} yesterdayLabel - Localized label shown for yesterday.
 * @returns {string} Formatted timestamp string.
 */
export const relativeDayTimestamp = (time, yesterdayLabel) => {
  const date = fromUnixTime(time);
  const locale = getActiveDateFnsLocale();
  if (isToday(date)) {
    return format(
      date,
      locale ? 'HH:mm' : 'h:mm a',
      ...(locale ? [{ locale }] : [])
    );
  }
  if (isYesterday(date)) return yesterdayLabel;
  if (isThisYear(date)) {
    return format(
      date,
      locale ? "d 'de' MMM" : 'MMM d',
      ...(locale ? [{ locale }] : [])
    );
  }
  return format(
    date,
    locale ? "d 'de' MMM, yyyy" : 'MMM d, yyyy',
    ...(locale ? [{ locale }] : [])
  );
};

/**
 * Converts a Unix timestamp to a relative time string (e.g., 3 hours ago).
 * @param {number} time - Unix timestamp.
 * @returns {string} Relative time string.
 */
export const dynamicTime = time => {
  const unixTime = fromUnixTime(time);
  const locale = getActiveDateFnsLocale();
  return formatDistanceToNow(unixTime, {
    addSuffix: true,
    ...(locale ? { locale } : {}),
  });
};

/**
 * Formats a Unix timestamp into a specified date format.
 * @param {number} time - Unix timestamp.
 * @param {string} [dateFormat='MMM d, yyyy'] - Desired date format.
 * @returns {string} Formatted date string.
 */
export const dateFormat = (time, df = 'MMM d, yyyy') => {
  const unixTime = fromUnixTime(time);
  return format(unixTime, df);
};

/**
 * Converts a detailed time description into a shorter format, optionally appending 'ago'.
 * @param {string} time - Detailed time description (e.g., 'a minute ago').
 * @param {boolean} [withAgo=false] - Whether to append 'ago' to the result.
 * @returns {string} Shortened time description.
 */
export const shortTimestamp = (time, withAgo = false) => {
  if (!time || typeof time !== 'string') return '';
  const trimmed = time.trim();

  // Portuguese (pt-BR) relative time compacting (e.g. "há 7 min", "há 7h", "há 2d")
  if (
    trimmed.startsWith('há ') ||
    trimmed.startsWith('em ') ||
    trimmed.includes('minuto') ||
    trimmed.includes('hora') ||
    trimmed.includes('mês') ||
    trimmed.includes('meses')
  ) {
    if (trimmed.includes('menos de um minuto')) return 'agora';
    const normalized = trimmed
      .replace(/^há\s+(?:cerca de|mais de|quase)\s+/i, 'há ')
      .replace(/^cerca de\s+/i, 'há ');

    return normalized
      .replace(/^há\s+um\s+minuto$/i, 'há 1 min')
      .replace(/^há\s+1\s+minuto$/i, 'há 1 min')
      .replace(/^há\s+(\d+)\s+minutos?$/i, 'há $1 min')
      .replace(/^há\s+uma\s+hora$/i, 'há 1h')
      .replace(/^há\s+1\s+hora$/i, 'há 1h')
      .replace(/^há\s+(\d+)\s+horas?$/i, 'há $1h')
      .replace(/^há\s+um\s+dia$/i, 'há 1d')
      .replace(/^há\s+1\s+dia$/i, 'há 1d')
      .replace(/^há\s+(\d+)\s+dias?$/i, 'há $1d')
      .replace(/^há\s+um\s+mês$/i, 'há 1m')
      .replace(/^há\s+1\s+mês$/i, 'há 1m')
      .replace(/^há\s+(\d+)\s+meses$/i, 'há $1m')
      .replace(/^há\s+um\s+ano$/i, 'há 1a')
      .replace(/^há\s+1\s+ano$/i, 'há 1a')
      .replace(/^há\s+(\d+)\s+anos?$/i, 'há $1a');
  }

  // This function takes a time string and converts it to a short time string
  // with the following format: 1m, 1h, 1d, 1mo, 1y
  // The function also takes an optional boolean parameter withAgo
  // which will add the word "ago" to the end of the time string
  const suffix = withAgo ? ' ago' : '';
  const timeMappings = {
    'less than a minute ago': 'now',
    'in less than a minute': 'now',
    'a minute ago': `1m${suffix}`,
    'an hour ago': `1h${suffix}`,
    'a day ago': `1d${suffix}`,
    'a month ago': `1mo${suffix}`,
    'a year ago': `1y${suffix}`,
  };
  // Check if the time string is one of the specific cases
  if (timeMappings[time]) {
    return timeMappings[time];
  }
  const convertToShortTime = time
    .replace(/about|over|almost|/g, '')
    .replace(' minute ago', `m${suffix}`)
    .replace(' minutes ago', `m${suffix}`)
    .replace(' hour ago', `h${suffix}`)
    .replace(' hours ago', `h${suffix}`)
    .replace(' day ago', `d${suffix}`)
    .replace(' days ago', `d${suffix}`)
    .replace(' month ago', `mo${suffix}`)
    .replace(' months ago', `mo${suffix}`)
    .replace(' year ago', `y${suffix}`)
    .replace(' years ago', `y${suffix}`);
  return convertToShortTime;
};

/**
 * Formats a duration in seconds into mm:ss or hh:mm:ss.
 * @param {number|string} durationInSeconds - Duration in seconds.
 * @returns {string} Formatted duration string. Empty string for invalid input.
 */
export const formatDuration = durationInSeconds => {
  if (durationInSeconds === null || durationInSeconds === undefined) return '';

  const totalSeconds = Number(durationInSeconds);
  if (Number.isNaN(totalSeconds) || totalSeconds < 0) return '';

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const mm = minutes.toString().padStart(2, '0');
  const ss = seconds.toString().padStart(2, '0');
  if (hours > 0) {
    return `${hours.toString().padStart(2, '0')}:${mm}:${ss}`;
  }
  return `${mm}:${ss}`;
};

/**
 * Calculates the difference in days between now and a given timestamp.
 * @param {Date} now - Current date/time.
 * @param {number} timestampInSeconds - Unix timestamp in seconds.
 * @returns {number} Number of days difference.
 */
export const getDayDifferenceFromNow = (now, timestampInSeconds) => {
  const date = new Date(timestampInSeconds * 1000);
  return differenceInDays(now, date);
};

/**
 * Checks if more than 24 hours have passed since a given timestamp.
 * Useful for determining if retry/refresh actions should be disabled.
 * @param {number} timestamp - Unix timestamp.
 * @returns {boolean} True if more than 24 hours have passed.
 */
export const hasOneDayPassed = timestamp => {
  if (!timestamp) return true; // Defensive check
  return getDayDifferenceFromNow(new Date(), timestamp) >= 1;
};
