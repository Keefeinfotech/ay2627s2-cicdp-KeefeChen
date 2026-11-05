import { Router } from 'express';
import { CalendarController } from './calendar.controller';
import {
  createEventValidation,
  updateEventValidation,
  getEventsQueryValidation,
} from './calendar.validation';
// Assuming authMiddleware exists in src/middleware
import { authenticate } from '../../middleware/authenticate';

const router = Router();
const controller = new CalendarController();

router.use(authenticate);

router.post('/', createEventValidation, controller.createEvent);
router.get('/', getEventsQueryValidation, controller.getEvents);
router.get('/conflicts', controller.checkScheduleConflicts);
router.patch('/:id', updateEventValidation, controller.updateEvent);
router.delete('/:id', controller.deleteEvent);

export default router;