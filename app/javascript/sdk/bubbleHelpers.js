import { addClasses, removeClasses, toggleClass } from './DOMHelpers';
import { IFrameHelper } from './IFrameHelper';
import {
  CHATWOOT_CLOSED,
  CHATWOOT_OPENED,
} from '../widget/constants/sdkEvents';
import { dispatchWindowEvent } from 'shared/helpers/CustomEventHelper';

export const bubbleSVG =
  'M240.808 240.808H122.123C56.6994 240.808 3.45695 187.562 3.45695 122.122C3.45695 56.7031 56.6994 3.45697 122.124 3.45697C187.566 3.45697 240.808 56.7031 240.808 122.122V240.808Z';

export const body = document.getElementsByTagName('body')[0];
export const widgetHolder = document.createElement('div');

export const bubbleHolder = document.createElement('div');
export const chatBubble = document.createElement('div');
export const closeBubble = document.createElement('button');
export const notificationBubble = document.createElement('span');

export const formatLauncherHoursFromConfig = () => {
  const customHours = window.chatwootSettings?.launcherHoursText;
  if (customHours) return customHours;

  const channelConfig = window.$chatwoot?.channelConfig;
  if (
    channelConfig?.workingHoursEnabled &&
    Array.isArray(channelConfig.workingHours)
  ) {
    const activeSlots = channelConfig.workingHours.filter(
      s => !s.closed_all_day && !s.closedAllDay
    );
    if (activeSlots.length > 0) {
      const first = activeSlots[0];
      const openH = first.open_hour ?? first.openHour ?? 9;
      const closeH = first.close_hour ?? first.closeHour ?? 18;
      const prefix =
        activeSlots.length === 7 ? 'Todos os dias' : 'Seg a Sex';
      return `${prefix}, das ${openH}h às ${closeH}h`;
    }
  }
  return 'Atendimento Online • Resposta Rápida';
};

export const setBubbleText = () => {
  const hoursEl = document.getElementById('woot-help-card-hours-sub');
  if (hoursEl) {
    hoursEl.innerText = formatLauncherHoursFromConfig();
  }
};

export const createBubbleIcon = ({ className, path, target }) => {
  const positionClass = `woot-elements--${window.$chatwoot.position}`;
  const bubbleClassName = `${className} ${positionClass} woot-widget--expanded woot-help-card`;
  const launcherTitle =
    window.chatwootSettings?.launcherTitle || 'PRECISA DE AJUDA?';
  const launcherSubtitle =
    window.chatwootSettings?.launcherSubtitle ||
    'Clique aqui e fale conosco!';

  target.innerHTML = '';
  target.setAttribute('role', 'button');
  target.setAttribute('tabindex', '0');
  target.setAttribute('aria-label', `${launcherTitle} ${launcherSubtitle}`);

  // Linha superior do card
  const topRow = document.createElement('div');
  topRow.className = 'woot-help-card__top';

  // Círculo verde com o balão de chat branco
  const iconWrap = document.createElement('div');
  iconWrap.className = 'woot-help-card__icon-wrap';

  const bubbleIcon = document.createElementNS(
    'http://www.w3.org/2000/svg',
    'svg'
  );
  bubbleIcon.setAttributeNS(null, 'id', 'woot-widget-bubble-icon');
  bubbleIcon.setAttributeNS(null, 'width', '24');
  bubbleIcon.setAttributeNS(null, 'height', '24');
  bubbleIcon.setAttributeNS(null, 'viewBox', '0 0 240 240');
  bubbleIcon.setAttributeNS(null, 'fill', 'none');
  bubbleIcon.setAttribute('xmlns', 'http://www.w3.org/2000/svg');

  const bubblePath = document.createElementNS(
    'http://www.w3.org/2000/svg',
    'path'
  );
  bubblePath.setAttributeNS(null, 'd', path);
  bubblePath.setAttributeNS(null, 'fill', '#FFFFFF');
  bubbleIcon.appendChild(bubblePath);

  const innerDot = document.createElement('span');
  innerDot.className = 'woot-help-card__icon-dot';

  iconWrap.appendChild(bubbleIcon);
  iconWrap.appendChild(innerDot);

  // Textos principais parametrizáveis por White-Label
  const textCol = document.createElement('div');
  textCol.className = 'woot-help-card__text-col';

  const titleEl = document.createElement('div');
  titleEl.className = 'woot-help-card__title';
  titleEl.innerText = launcherTitle;

  const subtitleEl = document.createElement('div');
  subtitleEl.className = 'woot-help-card__subtitle';
  subtitleEl.id = 'woot-widget--expanded__text';
  subtitleEl.innerText = launcherSubtitle;

  textCol.appendChild(titleEl);
  textCol.appendChild(subtitleEl);

  // Botão X no canto superior direito para recolher/minimizar o card se desejar
  const dismissBtn = document.createElement('span');
  dismissBtn.className = 'woot-help-card__dismiss';
  dismissBtn.setAttribute('role', 'button');
  dismissBtn.setAttribute('aria-label', 'Minimizar aviso');
  dismissBtn.innerHTML =
    '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>';

  dismissBtn.addEventListener('click', e => {
    e.stopPropagation();
    target.classList.toggle('woot-help-card--minimized');
  });

  topRow.appendChild(iconWrap);
  topRow.appendChild(textCol);
  topRow.appendChild(dismissBtn);

  // Divisor horizontal sutil
  const divider = document.createElement('div');
  divider.className = 'woot-help-card__divider';

  // Linha inferior (Horário de atendimento dinâmico por inbox / chatwootSettings)
  const bottomRow = document.createElement('div');
  bottomRow.className = 'woot-help-card__bottom';

  const clockWrap = document.createElement('div');
  clockWrap.className = 'woot-help-card__clock';
  clockWrap.innerHTML =
    '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#65c428" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"></circle><polyline points="12 7 12 12 15 14"></polyline></svg>';

  const hoursCol = document.createElement('div');
  hoursCol.className = 'woot-help-card__hours-col';

  const hoursTitle = document.createElement('div');
  hoursTitle.className = 'woot-help-card__hours-title';
  hoursTitle.innerText = 'Horário de atendimento';

  const hoursSub = document.createElement('div');
  hoursSub.className = 'woot-help-card__hours-sub';
  hoursSub.id = 'woot-help-card-hours-sub';
  hoursSub.innerText = formatLauncherHoursFromConfig();

  hoursCol.appendChild(hoursTitle);
  hoursCol.appendChild(hoursSub);

  const statusDot = document.createElement('span');
  statusDot.className = 'woot-help-card__status-dot';

  bottomRow.appendChild(clockWrap);
  bottomRow.appendChild(hoursCol);
  bottomRow.appendChild(statusDot);

  target.appendChild(topRow);
  target.appendChild(divider);
  target.appendChild(bottomRow);

  target.className = bubbleClassName;
  target.title = `${launcherTitle} ${launcherSubtitle}`;
  return target;
};

export const createBubbleHolder = hideMessageBubble => {
  if (hideMessageBubble) {
    addClasses(bubbleHolder, 'woot-hidden');
  }
  addClasses(bubbleHolder, 'woot--bubble-holder');
  bubbleHolder.id = 'cw-bubble-holder';
  bubbleHolder.dataset.turboPermanent = true;
  body.appendChild(bubbleHolder);
};

const handleBubbleToggle = newIsOpen => {
  IFrameHelper.events.onBubbleToggle(newIsOpen);

  if (newIsOpen) {
    dispatchWindowEvent({ eventName: CHATWOOT_OPENED });
  } else {
    dispatchWindowEvent({ eventName: CHATWOOT_CLOSED });
    chatBubble.focus();
  }
};

export const onBubbleClick = (props = {}) => {
  const { toggleValue } = props;
  const { isOpen } = window.$chatwoot;
  if (isOpen === toggleValue) return;

  const newIsOpen = toggleValue === undefined ? !isOpen : toggleValue;
  window.$chatwoot.isOpen = newIsOpen;

  toggleClass(chatBubble, 'woot--hide');
  toggleClass(closeBubble, 'woot--hide');
  toggleClass(widgetHolder, 'woot--hide');

  handleBubbleToggle(newIsOpen);
};

export const onClickChatBubble = () => {
  bubbleHolder.addEventListener('click', onBubbleClick);
};

export const addUnreadClass = () => {
  const holderEl = document.querySelector('.woot-widget-holder');
  addClasses(holderEl, 'has-unread-view');
};

export const removeUnreadClass = () => {
  const holderEl = document.querySelector('.woot-widget-holder');
  removeClasses(holderEl, 'has-unread-view');
};
