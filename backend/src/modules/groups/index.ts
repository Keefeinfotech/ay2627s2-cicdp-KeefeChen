import { Router } from "express";

import groupRoutes from "./group/group.routes";
import invitationRoutes from "./invitation/invitation.routes";

const router = Router();

router.use(groupRoutes);
router.use(invitationRoutes);

export default router;