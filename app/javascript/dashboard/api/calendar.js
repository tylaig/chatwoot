/* global axios */

import ApiClient from './ApiClient';

class CalendarAPI extends ApiClient {
  constructor() {
    super('calendar_schedules', { accountScoped: true });
  }

  getSchedules() {
    return axios.get(this.url);
  }

  createSchedule(payload) {
    return axios.post(this.url, { calendar_schedule: payload });
  }

  updateSchedule(id, payload) {
    return axios.patch(`${this.url}/${id}`, { calendar_schedule: payload });
  }

  deleteSchedule(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  getGoogleAuthUrl(id) {
    return axios.get(`${this.url}/${id}/google_auth_url`);
  }

  disconnectGoogle(id) {
    return axios.post(`${this.url}/${id}/disconnect_google`);
  }

  upsertAppointmentType(payload) {
    return axios.post(`${this.url}/appointment_types`, payload);
  }

  deleteAppointmentType(typeId) {
    return axios.delete(`${this.url}/appointment_types/${typeId}`);
  }

  getAppointments(params = {}) {
    const apptUrl = this.url.replace(
      '/calendar_schedules',
      '/calendar_appointments'
    );
    return axios.get(apptUrl, { params });
  }

  getAvailability(params = {}) {
    const apptUrl = this.url.replace(
      '/calendar_schedules',
      '/calendar_appointments'
    );
    return axios.get(`${apptUrl}/availability`, { params });
  }

  createAppointment(payload) {
    const apptUrl = this.url.replace(
      '/calendar_schedules',
      '/calendar_appointments'
    );
    return axios.post(apptUrl, { calendar_appointment: payload });
  }

  updateAppointment(id, payload) {
    const apptUrl = this.url.replace(
      '/calendar_schedules',
      '/calendar_appointments'
    );
    return axios.patch(`${apptUrl}/${id}`, { calendar_appointment: payload });
  }

  rescheduleAppointment(id, payload) {
    const apptUrl = this.url.replace(
      '/calendar_schedules',
      '/calendar_appointments'
    );
    return axios.post(`${apptUrl}/${id}/reschedule`, payload);
  }

  cancelAppointment(id, reason = '') {
    const apptUrl = this.url.replace(
      '/calendar_schedules',
      '/calendar_appointments'
    );
    return axios.post(`${apptUrl}/${id}/cancel`, { reason });
  }
}

export default new CalendarAPI();
